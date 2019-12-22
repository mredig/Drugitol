//
//  DrugAlarm+Convenience.swift
//  Drugitol
//
//  Created by Michael Redig on 12/16/19.
//  Copyright © 2019 Red_Egg Productions. All rights reserved.
//

import Foundation
import CoreData

extension DoseEntry {
	convenience init(timestamp: Date, for drug: DrugEntry, context: NSManagedObjectContext) {
		self.init(context: context)
		self.timestamp = timestamp
		self.drug = drug
	}

}
