//
//  DrugEntry+Convenience.swift
//  Drugitol
//
//  Created by Michael Redig on 12/16/19.
//  Copyright © 2019 Red_Egg Productions. All rights reserved.
//

import Foundation
import CoreData

extension DrugEntry {

	var drugAlarms: [DrugAlarm] {
		alarms?.compactMap { $0 as? DrugAlarm } ?? []
	}

	convenience init(name: String, isActive: Bool = true, context: NSManagedObjectContext) {
		self.init(context: context)
		self.name = name
		self.isActive = isActive
	}
}
