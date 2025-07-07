import logging
from datetime import datetime, timedelta
import re
import hashlib
import firebase_admin
import json
from pathlib import Path
from firebase_admin import credentials, db
from flask import Flask, request, jsonify

app = Flask(__name__)
# ==================== Firebase Setup ====================
FIREBASE_CREDENTIALS = "/Users/romanginiatov/PycharmProjects/seo1/alisa-711ad-firebase-adminsdk-fbsvc-9a2cebc232.json"
FIREBASE_DB_URL = "https://alisa-711ad-default-rtdb.firebaseio.com"

# Инициализация Firebase
cred = credentials.Certificate(FIREBASE_CREDENTIALS)
firebase_app = firebase_admin.initialize_app(cred, {
    'databaseURL': FIREBASE_DB_URL
})
root_ref = db.reference()
# Настройка логирования
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)
# ==================== Helpers ====================
MONTHS = {
    'января': 1, 'январь': 1, 'февраля': 2, 'февраль': 2,
    'марта': 3, 'март': 3, 'апреля': 4, 'апрель': 4,
    'мая': 5, 'май': 5, 'июня': 6, 'июнь': 6,
    'июля': 7, 'июль': 7, 'августа': 8, 'август': 8,
    'сентября': 9, 'сентябрь': 9, 'октября': 10, 'октябрь': 10,
    'ноября': 11, 'ноябрь': 11, 'декабря': 12, 'декабрь': 12
}


def email(user_id):

    hash_part = hashlib.md5(user_id.encode()).hexdigest()[:8]
    return f"shshmsnem@yandex.ru"


def extract_shopping_list(text):
    if text.lower().startswith('купить '):
        items_part = text[7:].strip()
        items = re.split(r',|\sи\s|\sа также\s|\s+', items_part)
        items = [item.strip().lower() for item in items if item.strip()]

        detailed_items = []
        for item in items:

            product_info = None
            for product in PRODUCTS_DATA.values():
                if product['short_name'].lower() == item:
                    product_info = product
                    break

            if product_info:
                detailed_items.append({
                    "short_name": product_info["short_name"],
                    "full_name": product_info["full_name"],
                    "price": product_info["price"],
                    "price_with_card": product_info["price_with_card"],
                    "url": product_info["url"],
                    "image_url": product_info["image_url"]
                })
            else:
                detailed_items.append({"short_name": item.capitalize()})

        return detailed_items if detailed_items else None
    return None

def load_products_data():
    try:
        with open('result.json', 'r', encoding='utf-8') as f:
            data = json.load(f)
            return {item['short_name'].lower(): item for item in data['results']}
    except Exception as e:
        logger.error(f"Error loading products data: {str(e)}")
        return {}

PRODUCTS_DATA = load_products_data()

def parse_date(command):

    command = command.lower()
    today = datetime.now()

    if 'сегодня' in command:
        return today.strftime('%d.%m.%Y')
    elif 'завтра' in command:
        return (today + timedelta(days=1)).strftime('%d.%m.%Y')
    elif 'послезавтра' in command:
        return (today + timedelta(days=2)).strftime('%d.%m.%Y')

    match = re.search(r'(\d{1,2})\s*(?:\.\s*)?(\d{1,2}|[а-я]+)?\s*(\d{4})?', command)
    if match:
        day = int(match.group(1))
        month_group = match.group(2)
        year_group = match.group(3)

        if month_group:
            if month_group.isdigit():
                month = int(month_group)
            else:
                month = MONTHS.get(month_group, today.month)
        else:
            month = today.month

        year = int(year_group) if year_group else today.year

        try:
            return f"{day:02d}.{month:02d}.{year}"
        except ValueError:
            return None
    return None


def get_or_create_user(user_id):

    emails = email(user_id)


    user_ref = root_ref.child('users').child(emails.replace('.', ''))
    user_data = user_ref.get()

    if not user_data:
        user_data = {
            'id': user_id,
            'created_at': datetime.now().isoformat(),
            'last_active': datetime.now().isoformat(),
            'tasks': {}
        }
        user_ref.set(user_data)
        logger.info(f"Created new user: {emails} with ID: {user_id}")
    else:
        user_ref.update({'last_active': datetime.now().isoformat()})

    return user_ref


def format_task_list(tasks):

    if not tasks:
        return "У вас пока нет задач."

    task_list = []
    shopping_groups = {}


    for task_id, task in tasks.items():
        if task.get('is_shopping'):
            parent_id = task.get('parent_task')
            if parent_id not in shopping_groups:
                shopping_groups[parent_id] = []
            shopping_groups[parent_id].append(task)
        else:
            task_list.append((task_id, task))


    result = []
    for i, (task_id, task) in enumerate(task_list, 1):
        result.append(f"{i}. {task['text']} (на {task['date']})")


    for parent_id, items in shopping_groups.items():
        first_item = items[0]
        shopping_items = "\n   • " + "\n   • ".join(item['text'] for item in items)
        result.append(f"{len(result) + 1}. Покупки на {first_item['date']}:{shopping_items}")

    return "Ваши задачи:\n" + "\n".join(result)


# ==================== Main Handler ====================


@app.route('/', methods=['POST'])

@app.route('/alice/', methods=['POST'])
def handle_alice_request():
    try:
        data = request.get_json()
        session = data.get('session', {})
        user_id = session.get('user_id', 'unknown_user')
        command = data.get('request', {}).get('command', '').lower()

        logger.info(f"Request from user {user_id}")


        user_ref = get_or_create_user(user_id)
        user_data = user_ref.get()
        user_email = user_ref.key.replace('_dot_', '_dot_')


        response_text = ""
        end_session = False

        if any(word in command for word in ['выход', 'завершить', 'стоп']):
            user_ref.child('state').set('idle')
            response_text = "Сеанс завершен. До свидания!"
            end_session = True

        elif 'помощь' in command or 'что ты умеешь' in command:
            response_text = ("Я могу: создавать задачи, показывать список задач и удалять задачи. "
                             "Скажите 'создай задачу', 'покажи задачи' или 'удалить задачу'.")
            end_session = False

        elif 'мой профиль' in command or 'моя почта' in command:
            response_text = f"Ваш email: {user_email}\nВаш ID: {user_data['id']}"
            end_session = False

        elif 'создай задачу' in command or 'новая задача' in command:
            user_ref.child('state').set('awaiting_date')
            response_text = "На какую дату создать задачу?"

        elif user_data.get('state') == 'awaiting_date':
            date = parse_date(command)
            if date:
                user_ref.update({
                    'state': 'awaiting_task',
                    'current_date': date
                })
                response_text = f"Хорошо, дата {date}. Что нужно сделать?"
            else:
                response_text = "Не поняла дату. Попробуйте сказать, например, '25 декабря', '12.05' или 'завтра'."


        elif user_data.get('state') == 'awaiting_task':

            if command.strip():
                task_id = datetime.now().strftime("%Y%m%d%H%M%S%f")
                shopping_items = extract_shopping_list(command)
                task_data = {
                    'text': command,
                    'date': user_data.get('current_date'),
                    'created_at': datetime.now().isoformat(),
                    'iot': 1
                }

                if shopping_items:
                    task_data['shopping_list'] = shopping_items
                    items_text = ", ".join(item['short_name'] for item in shopping_items)
                    response_text = f"Создан список покупок на {user_data.get('current_date')}: {items_text}"
                else:

                    response_text = f"Задача '{command}' создана на {user_data.get('current_date')}."
                user_ref.child('tasks').child(task_id).set(task_data)
                user_ref.child('state').set('idle')
                end_session = True
            else:

                response_text = "Не удалось создать задачу. Пожалуйста, повторите."

        elif 'покажи задачи' in command or 'список задач' in command:
            tasks = user_ref.child('tasks').get() or {}
            response_text = format_task_list(tasks)
            end_session = True

        elif 'удалить задачу' in command or 'удали задачу' in command:
            tasks = user_ref.child('tasks').get() or {}
            if not tasks:
                response_text = "У вас нет задач для удаления."
            else:
                user_ref.child('state').set('awaiting_task_deletion')
                response_text = (f"{format_task_list(tasks)}\n\n"
                                 "Какую задачу удалить? Укажите номер.")

        elif user_data.get('state') == 'awaiting_task_deletion':
            tasks = user_ref.child('tasks').get() or {}
            try:
                task_num = int(re.search(r'\d+', command).group()) - 1
                task_ids = list(tasks.keys())

                if 0 <= task_num < len(task_ids):
                    task_id = task_ids[task_num]
                    task_text = tasks[task_id]['text']
                    user_ref.child('tasks').child(task_id).delete()
                    user_ref.child('state').set('idle')
                    response_text = f"Задача '{task_text}' удалена."
                else:
                    response_text = "Задачи с таким номером не существует."
            except:
                response_text = "Не поняла номер задачи. Попробуйте еще раз."
            end_session = True

        else:
            response_text = ("Что хотите сделать?")

        return jsonify({
            'response': {
                'text': response_text,
                'tts': response_text,
                'end_session': end_session
            },
            'version': '1.0'
        })

    except Exception as e:
        logger.error(f"Error processing request: {str(e)}", exc_info=True)
        return jsonify({
            'response': {
                'text': "Произошла ошибка при обработке запроса. Пожалуйста, попробуйте позже.",
                'end_session': True
            },
            'version': '1.0'
        })


# ==================== Запуск сервера ====================
if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5500, debug=True)