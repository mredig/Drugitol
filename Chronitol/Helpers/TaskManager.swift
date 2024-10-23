import Foundation

@TaskManager.TaskManagerActor
enum TaskManager {
	@globalActor
	struct TaskManagerActor: GlobalActor {
		actor ActorType {}

		static let shared = ActorType()
	}

	struct RepeatingTask {
		let id = UUID()
		let frequency: TimeInterval
		let action: () async -> Void
	}

	static private(set) var tasks: [RepeatingTask] = []

	static func addTask(_ frequency: TimeInterval, action: @escaping () async -> Void) {
		tasks.append(RepeatingTask(frequency: frequency, action: action))
	}

	private static var runner: Task<Void, Never>?

	static var isRunning: Bool { runner != nil }

	static private var tracker: [UUID: Date] = [:]

	static func start() {
		guard isRunning == false else { return }
		runner = Task {
			defer { runner = nil }
			while true {
				do {
					try await Task.sleep(for: .seconds(60))

					let now = Date.now

					for task in tasks {
						let lastRun = tracker[task.id, default: .distantPast]

						if now.timeIntervalSince(lastRun) > task.frequency {
							tracker[task.id] = now

							Task {
								await task.action()
							}
						}
					}
				} catch {
					print("Task running failed: \(error)")
				}
			}
		}
	}
}
