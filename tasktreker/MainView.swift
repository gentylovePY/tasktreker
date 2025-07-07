import SwiftUI

enum TaskFilter: String, CaseIterable {
    case all = "Все"
    case today = "Сегодня"
    case upcoming = "Предстоящие"
    case completed = "Завершенные"
}

extension TaskFilter {
    var emptyStateMessage: String {
        switch self {
        case .all: return "Создайте свою первую задачу"
        case .today: return "Задачи на сегодня отсутствуют"
        case .upcoming: return "Предстоящих задач нет"
        case .completed: return "Нет завершенных задач"
        }
    }
}

struct MainView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var firebaseService = FirebaseService()
    @State private var showingAddTask = false
    @State private var selectedFilter: TaskFilter = .all
    @State private var isRefreshing = false
    
    private let userEmail = "shshmsnem@yandexru"
    private let primaryColor = Color(hex: "5E72EB")
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                
                if firebaseService.isLoading && !isRefreshing {
                    ProgressView()
                } else if let error = firebaseService.error {
                    ErrorView(error: error, retryAction: {
                        firebaseService.fetchUserTasks(email: userEmail)
                    })
                } else {
                    TaskListView(
                        tasks: filteredTasks,
                        firebaseService: firebaseService,
                        userEmail: userEmail,
                        primaryColor: primaryColor,
                        selectedFilter: $selectedFilter,
                        isRefreshing: $isRefreshing,
                        onRefresh: {
                            firebaseService.fetchUserTasks(email: userEmail)
                        }
                    )
                }
            }
            .navigationTitle("Мои задачи")
                      .toolbar {
                          ToolbarItem(placement: .navigationBarLeading) {
                              NavigationLink {
                                  ProfileView(firebaseService: firebaseService)
                                      .environmentObject(authManager)
                              } label: {
                                  Image(systemName: "person.circle.fill")
                                      .font(.title2)
                                      .foregroundColor(primaryColor)
                              }
                          }
                          
                          ToolbarItem(placement: .navigationBarTrailing) {
                              Button {
                                  showingAddTask = true
                              } label: {
                                  Image(systemName: "plus")
                                      .font(.headline)
                              }
                          }
                      }
                      .sheet(isPresented: $showingAddTask) {
                          AddTaskView(
                              firebaseService: firebaseService,
                              userEmail: userEmail
                          )
                      }
                  }
        .onAppear {
            firebaseService.fetchUserTasks(email: userEmail)
        }
    }
    
    private var filteredTasks: [Task] {
        let tasks = firebaseService.currentUserTasks
        
        switch selectedFilter {
        case .all:
            return tasks
        case .today:
            let today = DateFormatter.taskDateFormatter.string(from: Date())
            return tasks.filter { $0.date == today }
        case .upcoming:
            let today = DateFormatter.taskDateFormatter.string(from: Date())
            return tasks.filter { $0.date > today }
        case .completed:
            let today = DateFormatter.taskDateFormatter.string(from: Date())
            return tasks.filter { $0.date < today }
        }
    }
}

struct TaskListView: View {
    let tasks: [Task]
    @ObservedObject var firebaseService: FirebaseService
    let userEmail: String
    let primaryColor: Color
    @Binding var selectedFilter: TaskFilter
    @Binding var isRefreshing: Bool
    let onRefresh: () -> Void
    
    var body: some View {
        ScrollView {
            PullToRefresh(isRefreshing: $isRefreshing) {
                onRefresh()
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    isRefreshing = false
                }
            }
            
            FilterBar(selectedFilter: $selectedFilter, primaryColor: primaryColor)
                .padding(.horizontal)
            
            if tasks.isEmpty {
                EmptyStateView(filter: selectedFilter)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(tasks) { task in
                        TaskCard(
                            task: task,
                            primaryColor: primaryColor,
                            onDelete: {
                                firebaseService.deleteTask(task, for: userEmail)
                            }
                        )
                        .contextMenu {
                            Button(role: .destructive) {
                                firebaseService.deleteTask(task, for: userEmail)
                            } label: {
                                Label("Удалить", systemImage: "trash")
                            }
                        }
                    }
                }
                .padding()
            }
        }
    }
}

struct TaskCard: View {
    let task: Task
    let primaryColor: Color
    let onDelete: () -> Void
    
    // Добавляем вычисляемое свойство для определения важности задачи
    private var isImportant: Bool {
        task.iot == 2
    }
    
    var body: some View {
        NavigationLink {
            TaskDetailView(
                task: task,
                firebaseService: FirebaseService(),
                userEmail: "shshmsnem@yandexru"
            )
        } label: {
            HStack(spacing: 16) {
                statusIcon
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(task.text)
                        .font(.headline)
                        .lineLimit(2)
                    
                    HStack {
                        Image(systemName: "calendar")
                        Text(task.date)
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
            }
            .padding()
            .background(isImportant ? Color.red.opacity(0.1) : Color(.systemBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isImportant ? Color.red : Color.clear, lineWidth: isImportant ? 2 : 0)
            )
            .cornerRadius(12)
            .shadow(radius: 2)
            .scaleEffect(isImportant ? 1.02 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isImportant)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var statusIcon: some View {
        ZStack {
            Circle()
                .fill(statusColor.opacity(0.2))
                .frame(width: 40, height: 40)
            
            Image(systemName: statusIconName)
                .foregroundColor(statusColor)
        }
    }
    
    private var statusColor: Color {
        if isOverdue {
            return .red
        } else if isDueToday {
            return .orange
        } else if isImportant {
            return .red
        } else {
            return primaryColor
        }
    }
    
    private var statusIconName: String {
        if isOverdue {
            return "exclamationmark"
        } else if isDueToday {
            return "clock.fill"
        } else if isImportant {
            return "exclamationmark.triangle.fill"
        } else {
            return "checkmark.circle.fill"
        }
    }
    
    private var isDueToday: Bool {
        let today = DateFormatter.taskDateFormatter.string(from: Date())
        return task.date == today
    }
    
    private var isOverdue: Bool {
        guard let taskDate = DateFormatter.taskDateFormatter.date(from: task.date) else {
            return false
        }
        return taskDate < Date()
    }
}


struct TaskDetailView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var firebaseService: FirebaseService
    let userEmail: String
    
    @State var task: Task
    @State private var isEditing = false
    @State private var editedText: String
    @State private var editedDate: Date
    @State private var isImportant: Bool
    @State private var showingDeleteAlert = false
    @State private var cardOffset: CGSize = .zero
    @State private var isAnimating = false
    
    private let primaryColor = Color(hex: "5E72EB")
    
    init(task: Task, firebaseService: FirebaseService, userEmail: String) {
        self.task = task
        self.firebaseService = firebaseService
        self.userEmail = userEmail
        self._editedText = State(initialValue: task.text)
        self._editedDate = State(initialValue: DateFormatter.taskDateFormatter.date(from: task.date) ?? Date())
        self._isImportant = State(initialValue: task.iot == 2)
    }
    
    var body: some View {
        ZStack {
            RadialGradient(
                gradient: Gradient(colors: [Color(.systemGroupedBackground), Color(.systemGroupedBackground).opacity(0.7)]),
                center: .center,
                startRadius: isAnimating ? 100 : 300,
                endRadius: isAnimating ? 500 : 100
            )
            .ignoresSafeArea()
            .animation(Animation.easeInOut(duration: 8).repeatForever(), value: isAnimating)
            
            ScrollView {
                VStack(spacing: 20) {
                  
                    VStack(alignment: .leading, spacing: 16) {
                        if isEditing {
                           
                            TextField("Описание задачи", text: $editedText, axis: .vertical)
                                .font(.title3)
                                .padding()
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(12)
                                .transition(.opacity)
                            
                            Toggle(isOn: $isImportant) {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(isImportant ? .red : .gray)
                                    Text("Важная задача")
                                        .font(.headline)
                                        .foregroundColor(isImportant ? .red : .primary)
                                }
                            }
                            .toggleStyle(SwitchToggleStyle(tint: .red))
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(12)
                            
                            DatePicker(
                                "Дата выполнения",
                                selection: $editedDate,
                                in: Date()...,
                                displayedComponents: .date
                            )
                            .datePickerStyle(.graphical)
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(12)
                        } else {
                           
                            Text(task.text)
                                .font(.title3)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(VisualEffectView(.systemThinMaterial))
                                .cornerRadius(12)
                                .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
                            
                            if isImportant {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.red)
                                    Text("Важная задача")
                                        .font(.subheadline)
                                        .foregroundColor(.red)
                                }
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.red, lineWidth: 1)
                                )
                            }
                            
                            HStack {
                                Image(systemName: "calendar")
                                    .foregroundColor(primaryColor)
                                Text(task.date)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(VisualEffectView(.systemThinMaterial))
                            .cornerRadius(12)
                            .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
                            
                            HStack {
                                Image(systemName: "clock")
                                    .foregroundColor(primaryColor)
                                Text("Создано: \(formattedDate(task.createdAt))")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            .padding(.horizontal)
                            
                            
                            if let shoppingList = task.shopping_list, !shoppingList.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Список покупок")
                                        .font(.headline)
                                        .padding(.top, 8)
                                    
                                    ForEach(shoppingList) { item in
                                        ShoppingItemCard(item: item)
                                    }
                                }
                                .padding(.top, 8)
                            }
                        }
                    }
                    .padding()
                    .background(VisualEffectView(.systemMaterial))
                    .cornerRadius(20)
                    .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
                    .offset(cardOffset)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                withAnimation(.interactiveSpring()) {
                                    cardOffset = value.translation
                                }
                            }
                            .onEnded { value in
                                if abs(value.translation.width) > 100 {
                                    dismiss()
                                } else {
                                    withAnimation(.spring()) {
                                        cardOffset = .zero
                                    }
                                }
                            }
                    )
                    
                   
                    HStack(spacing: 20) {
                        if isEditing {
                            Button(action: cancelEditing) {
                                HStack {
                                    Image(systemName: "xmark")
                                    Text("Отменить")
                                }
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .foregroundColor(.red)
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(12)
                            }
                            
                            Button(action: saveChanges) {
                                HStack {
                                    Image(systemName: "checkmark")
                                    Text("Сохранить")
                                }
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .foregroundColor(.white)
                                .background(primaryColor)
                                .cornerRadius(12)
                                .shadow(color: primaryColor.opacity(0.3), radius: 10, y: 5)
                            }
                        } else {
                            Button(action: {
                                withAnimation(.spring()) {
                                    isEditing = true
                                }
                            }) {
                                HStack {
                                    Image(systemName: "pencil")
                                    Text("Изменить")
                                }
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .foregroundColor(primaryColor)
                                .background(primaryColor.opacity(0.1))
                                .cornerRadius(12)
                            }
                            
                            Button(action: {
                                withAnimation {
                                    showingDeleteAlert = true
                                }
                            }) {
                                HStack {
                                    Image(systemName: "trash")
                                    Text("Удалить")
                                }
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .foregroundColor(.red)
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(12)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
                .padding(.top, 30)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(isEditing ? "Редактирование" : "Детали задачи")
                    .font(.headline)
                    .foregroundColor(.primary)
                    .transition(.opacity)
            }
        }
        .alert("Удалить задачу?", isPresented: $showingDeleteAlert) {
            Button("Удалить", role: .destructive) {
                withAnimation {
                    firebaseService.deleteTask(task, for: userEmail)
                    dismiss()
                }
            }
            Button("Отмена", role: .cancel) {}
        }
        .onAppear {
            withAnimation {
                isAnimating = true
            }
        }
    }
    
    private func saveChanges() {
        let updatedDate = DateFormatter.taskDateFormatter.string(from: editedDate)
        let updatedTask = Task(
            id: task.id,
            text: editedText,
            date: updatedDate,
            createdAt: task.createdAt,
            priority: task.priority,
            iot: isImportant ? 2 : 1,
            shopping_list: task.shopping_list
        )
        
        firebaseService.updateTask(updatedTask, for: userEmail)
        
        withAnimation(.spring()) {
            task = updatedTask
            isEditing = false
        }
    }
    
    private func cancelEditing() {
        withAnimation(.spring()) {
            editedText = task.text
            editedDate = DateFormatter.taskDateFormatter.date(from: task.date) ?? Date()
            isImportant = task.iot == 2
            isEditing = false
        }
    }
    
    private func formattedDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .long
            displayFormatter.timeStyle = .short
            return displayFormatter.string(from: date)
        }
        return dateString
    }
}

struct ShoppingItemCard: View {
    let item: ShoppingItem
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            AsyncImage(url: URL(string: item.image_url)) { image in
                image.resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 80, height: 80)
                    .cornerRadius(8)
                    .clipped()
            } placeholder: {
                ProgressView()
                    .frame(width: 80, height: 80)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(item.full_name)
                    .font(.subheadline)
                    .bold()
                
                HStack {
                    Text(item.price)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    
                    if item.price != item.price_with_card {
                        Text(item.price_with_card)
                            .font(.footnote)
                            .foregroundColor(.green)
                    }
                }
                
                Button(action: {
                    if let url = URL(string: item.url) {
                        UIApplication.shared.open(url)
                    }
                }) {
                    Text("Открыть в магазине")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                .padding(.top, 4)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray5), lineWidth: 1)
        )
    }
}
    


struct VisualEffectView: UIViewRepresentable {
    var effect: UIVisualEffect?
    
    init(_ effect: UIBlurEffect.Style) {
        self.effect = UIBlurEffect(style: effect)
    }
    
    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: effect)
    }
    
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = effect
    }
}

struct TaskDetailView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            TaskDetailView(
                task: Task(
                    id: "1",
                    text: "Пример задачи с длинным текстом для демонстрации интерфейса",
                    date: "01.01.2025",
                    createdAt: "2025-01-01T00:00:00.000000"
                ),
                firebaseService: FirebaseService(),
                userEmail: "test@example.com"
            )
        }
    }
}


struct FilterBar: View {
    @Binding var selectedFilter: TaskFilter
    let primaryColor: Color
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(TaskFilter.allCases, id: \.self) { filter in
                    Button {
                        selectedFilter = filter
                    } label: {
                        Text(filter.rawValue)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(selectedFilter == filter ? primaryColor : Color(.systemBackground))
                            .foregroundColor(selectedFilter == filter ? .white : primaryColor)
                            .cornerRadius(20)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(primaryColor, lineWidth: 1)
                            )
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }
}

struct EmptyStateView: View {
    let filter: TaskFilter
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text(filter.emptyStateMessage)
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

struct ErrorView: View {
    let error: String
    let retryAction: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(.red)
            Text("Ошибка")
                .font(.headline)
            Text(error)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button("Повторить", action: retryAction)
                .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

struct PullToRefresh: View {
    @Binding var isRefreshing: Bool
    var action: () -> Void
    
    var body: some View {
        GeometryReader { geometry in
            if isRefreshing {
                ProgressView()
                    .frame(width: geometry.size.width)
            }
        }
        .frame(height: isRefreshing ? 50 : 0)
        .onChange(of: isRefreshing) { refreshing in
            if refreshing {
                action()
            }
        }
    }
}

extension DateFormatter {
    static let taskDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy"
        return formatter
    }()
}

extension AsyncImage {
    func productImageStyle() -> some View {
        self
            .aspectRatio(contentMode: .fill)
            .frame(width: 80, height: 80)
            .cornerRadius(8)
            .clipped()
    }
}
