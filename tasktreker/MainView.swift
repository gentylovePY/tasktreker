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
    @State private var newTaskText = ""
    @State private var selectedDate = Date()
    @State private var selectedFilter: TaskFilter = .all
    @State private var isRefreshing = false
    
    private let userEmail = "shshmsnem@yandex_dot_ru"
    
    private let primaryColor = Color(hex: "5E72EB")
    private let secondaryColor = Color(hex: "FF9190")
    private let bgGradient = LinearGradient(
        gradient: Gradient(colors: [Color(hex: "F6F7FF"), Color(hex: "EFF1FF")]),
        startPoint: .top,
        endPoint: .bottom
    )
    
    var body: some View {
        ZStack {
            bgGradient.ignoresSafeArea()
            
            VStack(spacing: 0) {
                header
                
                if firebaseService.isLoading && !isRefreshing {
                    loadingView
                } else if let error = firebaseService.error {
                    errorView(error: error)
                } else {
                    content
                }
            }
            .sheet(isPresented: $showingAddTask) {
                AddTaskView(
                    isPresented: $showingAddTask,
                    taskText: $newTaskText,
                    selectedDate: $selectedDate,
                    onAdd: addTask
                )
                .accentColor(primaryColor)
            }
        }
        .onAppear {
            firebaseService.fetchUserTasks(email: userEmail)
        }
    }
    
    private var header: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Мои задачи")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: "2D3748"))
                
                Spacer()
                
                Button(action: { authManager.logout() }) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(primaryColor)
                }
            }
            .padding(.horizontal, 24)
            
            filterBar
        }
        .padding(.top, 16)
        .padding(.bottom, 8)
    }
    
    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(TaskFilter.allCases, id: \.self) { filter in
                    FilterPill(
                        title: filter.rawValue,
                        isSelected: selectedFilter == filter,
                        color: primaryColor
                    )
                    .onTapGesture {
                        withAnimation(.spring()) {
                            selectedFilter = filter
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
        }
    }
    
    private var content: some View {
        ScrollView {
            PullToRefresh(isRefreshing: $isRefreshing) {
                firebaseService.fetchUserTasks(email: userEmail)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    isRefreshing = false
                }
            }
            
            LazyVStack(spacing: 16) {
                if filteredTasks.isEmpty {
                    emptyState
                } else {
                    ForEach(filteredTasks) { task in
                        TaskCard(task: task, primaryColor: primaryColor) {
                            deleteTask(task)
                        }
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .leading)),
                            removal: .opacity.combined(with: .scale(scale: 0.8))
                        ))
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .overlay(
            addButton, alignment: .bottomTrailing
        )
    }
    
    private var addButton: some View {
        Button(action: { showingAddTask = true }) {
            Image(systemName: "plus")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(primaryColor)
                .clipShape(Circle())
                .shadow(color: primaryColor.opacity(0.3), radius: 10, x: 0, y: 5)
                .padding(24)
        }
    }
    
    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: primaryColor))
                .scaleEffect(1.5)
            Spacer()
        }
    }
    
    private func errorView(error: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundColor(secondaryColor)
            Text("Ошибка загрузки")
                .font(.title2.bold())
            Text(error)
                .multilineTextAlignment(.center)
                .foregroundColor(.gray)
            Button("Повторить") {
                firebaseService.fetchUserTasks(email: userEmail)
            }
            .buttonStyle(PrimaryButtonStyle(color: primaryColor))
            .padding(.top, 8)
            Spacer()
        }
        .padding()
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(primaryColor.opacity(0.3))
            Text("Нет задач")
                .font(.title3.bold())
            Text(selectedFilter.emptyStateMessage)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .padding(40)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.7))
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
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
    
    private func addTask() {
        guard !newTaskText.isEmpty else { return }
        
        let dateFormatter = DateFormatter.taskDateFormatter
        let dateString = dateFormatter.string(from: selectedDate)
        
        let taskId = "\(Int(Date().timeIntervalSince1970 * 1000))"
        let createdAt = ISO8601DateFormatter().string(from: Date())
        
        let task = Task(
            id: taskId,
            text: newTaskText,
            date: dateString,
            createdAt: createdAt
        )
        
        firebaseService.addTask(task, for: userEmail)
        newTaskText = ""
    }
    
    private func deleteTask(_ task: Task) {
        withAnimation {
            firebaseService.deleteTask(task, for: userEmail)
        }
    }
}

struct TaskCard: View {
    let task: Task
    let primaryColor: Color
    let onDelete: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        HStack(spacing: 16) {
            statusIcon
            
            VStack(alignment: .leading, spacing: 6) {
                Text(task.text)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .lineLimit(2)
                
                HStack {
                    Image(systemName: "calendar")
                        .font(.caption)
                    Text(task.date)
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                }
                .foregroundColor(.gray)
            }
            
            Spacer()
            
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color.red.opacity(0.7))
                    .padding(8)
                    .background(Color.red.opacity(0.1))
                    .clipShape(Circle())
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
        .scaleEffect(isPressed ? 0.98 : 1)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        .gesture(
            LongPressGesture(minimumDuration: 0.1)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
    
    private var statusIcon: some View {
        ZStack {
            Circle()
                .fill(statusColor.opacity(0.2))
                .frame(width: 40, height: 40)
            
            Image(systemName: statusIconName)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(statusColor)
        }
    }
    
    private var statusColor: Color {
        if isOverdue {
            return .red
        } else if isDueToday {
            return .orange
        } else {
            return primaryColor
        }
    }
    
    private var statusIconName: String {
        if isOverdue {
            return "exclamationmark"
        } else if isDueToday {
            return "clock.fill"
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

struct FilterPill: View {
    let title: String
    let isSelected: Bool
    let color: Color
    
    var body: some View {
        Text(title)
            .font(.system(size: 14, weight: .semibold, design: .rounded))
            .foregroundColor(isSelected ? .white : color)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(isSelected ? color : color.opacity(0.1))
            .cornerRadius(20)
    }
}

struct AddTaskView: View {
    @Binding var isPresented: Bool
    @Binding var taskText: String
    @Binding var selectedDate: Date
    let onAdd: () -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                Form {
                    Section {
                        TextField("Например: 'Купить молоко'", text: $taskText)
                            .font(.system(size: 16, weight: .regular, design: .rounded))
                        
                        DatePicker(
                            "Дата выполнения",
                            selection: $selectedDate,
                            in: Date()...,
                            displayedComponents: .date
                        )
                        .font(.system(size: 16, weight: .regular, design: .rounded))
                    }
                    .listRowBackground(Color(.systemGroupedBackground))
                }
                
                Button(action: {
                    onAdd()
                    isPresented = false
                }) {
                    Text("Добавить задачу")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                }
                .buttonStyle(PrimaryButtonStyle(color: Color(hex: "5E72EB")))
                .padding()
                .disabled(taskText.isEmpty)
            }
            .navigationTitle("Новая задача")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        isPresented = false
                    }
                }
            }
        }
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    let color: Color
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.white)
            .background(color)
            .cornerRadius(12)
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
    }
}

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(), value: configuration.isPressed)
    }
}

struct PullToRefresh: View {
    @Binding var isRefreshing: Bool
    let action: () -> Void
    
    var body: some View {
        GeometryReader { geometry in
            if isRefreshing {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .gray))
                    .frame(width: geometry.size.width)
                    .offset(y: -20)
            }
        }
        .frame(height: isRefreshing ? 50 : 0)
    }
}

extension DateFormatter {
    static let taskDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy"
        return formatter
    }()
}
