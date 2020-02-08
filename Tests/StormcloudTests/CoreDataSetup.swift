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
		raindropEntity.name = "Raindrop"
		raindropEntity.managedObjectClassName = NSStringFromClass(Raindrop.self)

		let tagEntity = NSEntityDescription()
		tagEntity.name = "Tag"
		tagEntity.managedObjectClassName = NSStringFromClass(Tag.self)

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
		
        let raindropColourAttribute = NSAttributeDescription()
		raindropColourAttribute.name = "colour"
		raindropColourAttribute.isOptional = true
		raindropColourAttribute.attributeType = .transformableAttributeType
		
        let raindropValueAttribute = NSAttributeDescription()
		raindropValueAttribute.name = "raindropValue"
		raindropValueAttribute.isOptional = true
		raindropValueAttribute.attributeType = .decimalAttributeType
		raindropValueAttribute.defaultValue = 0.0
		
        let raindropTimesFallenAttribute = NSAttributeDescription()
		raindropTimesFallenAttribute.name = "timesFallen"
		raindropTimesFallenAttribute.isOptional = true
		raindropTimesFallenAttribute.attributeType = .integer64AttributeType
		raindropTimesFallenAttribute.defaultValue = 0
		
        let raindropTypeAttribute = NSAttributeDescription()
		raindropTypeAttribute.name = "type"
		raindropTypeAttribute.isOptional = true
		raindropTypeAttribute.attributeType = .stringAttributeType
		
		let tagNameAttribute = NSAttributeDescription()
		tagNameAttribute.name = "name"
		tagNameAttribute.isOptional = true
		tagNameAttribute.attributeType = .stringAttributeType
		
		// Relationships
		
		let cloudsToRaindrops = NSRelationshipDescription()
		cloudsToRaindrops.name = "raindrops"
		cloudsToRaindrops.isOptional = true
		cloudsToRaindrops.deleteRule = .cascadeDeleteRule
		cloudsToRaindrops.destinationEntity = raindropEntity
		
		let cloudsToTags = NSRelationshipDescription()
		cloudsToTags.name = "tags"
		cloudsToTags.isOptional = true
		cloudsToTags.deleteRule = .nullifyDeleteRule
		cloudsToTags.destinationEntity = tagEntity
		
		let raindropToCloud = NSRelationshipDescription()
		raindropToCloud.name = "cloud"
		raindropToCloud.isOptional = true
		raindropToCloud.deleteRule = .nullifyDeleteRule
		raindropToCloud.destinationEntity = cloudEntity
		raindropToCloud.maxCount = 1
		
		let tagToCloud = NSRelationshipDescription()
		tagToCloud.name = "clouds"
		tagToCloud.isOptional = true
		tagToCloud.deleteRule = .nullifyDeleteRule
		tagToCloud.destinationEntity = cloudEntity
		
		cloudsToRaindrops.inverseRelationship = raindropToCloud
		cloudsToTags.inverseRelationship = tagToCloud
		
		cloudEntity.properties = [cloudAddedAttribute, chanceOfRainAttribute, didRainAttribute, imageAttribute, nameAttribute, orderAttribute, cloudsToRaindrops, cloudsToTags]
		raindropEntity.properties = [raindropColourAttribute, raindropValueAttribute, raindropTimesFallenAttribute, raindropTypeAttribute, raindropToCloud]
		tagEntity.properties = [tagNameAttribute, tagToCloud]
		
		let model = NSManagedObjectModel()
		model.entities = [ cloudEntity, raindropEntity, tagEntity ]
		return model
	}
}


