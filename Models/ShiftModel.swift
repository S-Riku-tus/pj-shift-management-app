import Foundation
import CoreData

// Core Dataエンティティ定義（ShiftModelApp.xcdatamodeldのエンティティに対応）
class ShiftModel: NSManagedObject {
    @NSManaged var id: UUID?
    @NSManaged var date: Date?
    @NSManaged var startTime: Date?
    @NSManaged var endTime: Date?
    @NSManaged var notes: String?
}

// OCR認識後のシフト情報を一時的に保持するための構造体
struct ShiftEntry: Identifiable {
    let id = UUID()
    let date: Date
    let startTime: Date
    let endTime: Date
    let notes: String?
}

// Core Dataモデル定義
extension ShiftModel {
    static func createShiftModelCoreDataModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()
        
        // シフトエンティティ定義
        let shiftEntity = NSEntityDescription()
        shiftEntity.name = "ShiftModel"
        shiftEntity.managedObjectClassName = NSStringFromClass(ShiftModel.self)
        
        // 属性定義
        let idAttribute = NSAttributeDescription()
        idAttribute.name = "id"
        idAttribute.attributeType = .UUIDAttributeType
        idAttribute.isOptional = false
        
        let dateAttribute = NSAttributeDescription()
        dateAttribute.name = "date"
        dateAttribute.attributeType = .dateAttributeType
        dateAttribute.isOptional = false
        
        let startTimeAttribute = NSAttributeDescription()
        startTimeAttribute.name = "startTime"
        startTimeAttribute.attributeType = .dateAttributeType
        startTimeAttribute.isOptional = false
        
        let endTimeAttribute = NSAttributeDescription()
        endTimeAttribute.name = "endTime"
        endTimeAttribute.attributeType = .dateAttributeType
        endTimeAttribute.isOptional = false
        
        let notesAttribute = NSAttributeDescription()
        notesAttribute.name = "notes"
        notesAttribute.attributeType = .stringAttributeType
        notesAttribute.isOptional = true
        
        // エンティティに属性を追加
        shiftEntity.properties = [
            idAttribute,
            dateAttribute,
            startTimeAttribute,
            endTimeAttribute,
            notesAttribute
        ]
        
        // モデルにエンティティを追加
        model.entities = [shiftEntity]
        
        return model
    }
}