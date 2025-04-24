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
    
    private let userEmail = "shshmsnem@yandex_dot_ru"
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
    
    var body: some View {
        NavigationLink {
            TaskDetailView(
                task: task,
                firebaseService: FirebaseService(),
                userEmail: "shshmsnem@yandex_dot_ru"
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
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(radius: 2)
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

struct TaskDetailView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var firebaseService: FirebaseService
    let userEmail: String
    
    @State var task: Task
    @State private var isEditing = false
    @State private var editedText: String
    @State private var editedDate: Date
    @State private var showingDeleteAlert = false
    
    init(task: Task, firebaseService: FirebaseService, userEmail: String) {
        self.task = task
        self.firebaseService = firebaseService
        self.userEmail = userEmail
        self._editedText = State(initialValue: task.text)
        self._editedDate = State(initialValue: DateFormatter.taskDateFormatter.date(from: task.date) ?? Date())
    }
    
    var body: some View {
        Form {
            if isEditing {
                Section {
                    TextField("Текст задачи", text: $editedText)
                    DatePicker("Дата выполнения", selection: $editedDate, displayedComponents: .date)
                }
            } else {
                Section {
                    Text(task.text)
                    Text(task.date)
                }
                
                Section {
                    Text("Создано: \(formattedDate(task.createdAt))")
                        .foregroundColor(.secondary)
                }
            }
            
            if !isEditing {
                Section {
                    Button(role: .destructive) {
                        showingDeleteAlert = true
                    } label: {
                        Label("Удалить задачу", systemImage: "trash")
                    }
                }
            }
        }
        .navigationTitle(isEditing ? "Редактирование" : "Детали задачи")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if isEditing {
                    Button("Сохранить") {
                        saveChanges()
                    }
                } else {
                    Button("Изменить") {
                        isEditing = true
                    }
                }
            }
        }
        .alert("Удалить задачу?", isPresented: $showingDeleteAlert) {
            Button("Удалить", role: .destructive) {
                firebaseService.deleteTask(task, for: userEmail)
                dismiss()
            }
            Button("Отмена", role: .cancel) {}
        }
    }
    
    private func saveChanges() {
        let updatedDate = DateFormatter.taskDateFormatter.string(from: editedDate)
        let updatedTask = Task(
            id: task.id,
            text: editedText,
            date: updatedDate,
            createdAt: task.createdAt
        )
        
        firebaseService.updateTask(updatedTask, for: userEmail)
        task = updatedTask
        isEditing = false
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

struct AddTaskView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var firebaseService: FirebaseService
    let userEmail: String
    
    @State private var text = ""
    @State private var date = Date()
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Текст задачи", text: $text)
                    DatePicker("Дата выполнения", selection: $date, displayedComponents: .date)
                }
            }
            .navigationTitle("Новая задача")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Добавить") {
                        addTask()
                    }
                    .disabled(text.isEmpty)
                }
            }
        }
    }
    
    private func addTask() {
        let taskId = "\(Int(Date().timeIntervalSince1970 * 1000))"
        let createdAt = ISO8601DateFormatter().string(from: Date())
        let dateString = DateFormatter.taskDateFormatter.string(from: date)
        
        let task = Task(
            id: taskId,
            text: text,
            date: dateString,
            createdAt: createdAt
        )
        
        firebaseService.addTask(task, for: userEmail)
        dismiss()
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
