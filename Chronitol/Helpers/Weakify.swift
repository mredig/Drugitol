import Foundation

public protocol Weakify: AnyObject {}

public extension Weakify {
	func weakify(_ block: @escaping (Self) -> Void) -> () -> Void {
		return { [weak self] in
			guard let self = self else { return }
			block(self)
		}
	}

	@discardableResult func weakify<OptReturn>(_ block: @escaping (Self) -> OptReturn?) -> () -> OptReturn? {
		return { [weak self] in
			guard let self = self else { return nil }
			return block(self)
		}
	}

	func weakify<A>(_ block: @escaping (A, Self) -> Void) -> (A) -> Void {
		return { [weak self] in
			guard let self = self else { return }
			block($0, self)
		}
	}

	@discardableResult func weakify<A, OptReturn>(_ block: @escaping (A, Self) -> OptReturn?) -> (A) -> OptReturn? {
		return { [weak self] in
			guard let self = self else { return nil }
			return block($0, self)
		}
	}

	func weakify<A, B>(_ block: @escaping (A, B, Self) -> Void) -> (A, B) -> Void {
		return { [weak self] in
			guard let self = self else { return }
			block($0, $1, self)
		}
	}

	@discardableResult func weakify<A, B, OptReturn>(_ block: @escaping (A, B, Self) -> OptReturn?) -> (A, B) -> OptReturn? {
		return { [weak self] in
			guard let self = self else { return nil }
			return block($0, $1, self)
		}
	}

	@discardableResult func weakify<A, B, Return>(defaultReturn: Return, _ block: @escaping (A, B, Self) -> Return) -> (A, B) -> Return {
		return { [weak self] in
			guard let self = self else { return defaultReturn }
			return block($0, $1, self)
		}
	}

	func weakify<A, B, C>(_ block: @escaping (A, B, C, Self) -> Void) -> (A, B, C) -> Void {
		return { [weak self] in
			guard let self = self else { return }
			block($0, $1, $2, self)
		}
	}

	@discardableResult func weakify<A, B, C, OptReturn>(_ block: @escaping (A, B, C, Self) -> OptReturn?) -> (A, B, C) -> OptReturn? {
		return { [weak self] in
			guard let self = self else { return nil }
			return block($0, $1, $2, self)
		}
	}
}

extension NSObject: Weakify {}
