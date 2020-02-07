//
//  File.swift
//  
//
//  Created by Simon Fairbairn on 08/02/2020.
//

import Foundation
import CoreData

class StormcloudTestModel {
	
	func setupModel() -> NSManagedObjectModel {
		let cloudEntity = NSEntityDescription()
		cloudEntity.name = "Cloud"
		cloudEntity.managedObjectClassName = NSStringFromClass(Cloud.self)

		let raindropEntity = NSEntityDescription()
		cloudEntity.name = "Raindrop"
		cloudEntity.managedObjectClassName = NSStringFromClass(Raindrop.self)

		let tagEntity = NSEntityDescription()
		cloudEntity.name = "Tag"
		cloudEntity.managedObjectClassName = NSStringFromClass(Tag.self)

		let cloudAddedAttribute = NSAttributeDescription()
		cloudAddedAttribute.name = "added"
		cloudAddedAttribute.isOptional = true
		cloudAddedAttribute.attributeType = .dateAttributeType

		let chanceOfRainAttribute = NSAttributeDescription()
		chanceOfRainAttribute.name = "chanceOfRain"
		chanceOfRainAttribute.isOptional = true
		chanceOfRainAttribute.attributeType = .floatAttributeType

		let didRainAttribute = NSAttributeDescription()
		didRainAttribute.name = "didRain"
		didRainAttribute.isOptional = true
		didRainAttribute.attributeType = .booleanAttributeType
		
		let imageAttribute = NSAttributeDescription()
		imageAttribute.name = "image"
		imageAttribute.isOptional = true
		imageAttribute.attributeType = .binaryDataAttributeType

		let nameAttribute = NSAttributeDescription()
		nameAttribute.name = "name"
		nameAttribute.isOptional = true
		nameAttribute.attributeType = .stringAttributeType

		let orderAttribute = NSAttributeDescription()
		orderAttribute.name = "order"
		orderAttribute.isOptional = true
		orderAttribute.attributeType = .integer16AttributeType

		cloudEntity.properties = [cloudAddedAttribute, chanceOfRainAttribute, didRainAttribute, imageAttribute, nameAttribute, orderAttribute]
		
		
		
		let model = NSManagedObjectModel()
		model.entities = [ cloudEntity ]
		return model
	}
}


