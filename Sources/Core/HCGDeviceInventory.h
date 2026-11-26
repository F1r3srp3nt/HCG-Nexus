#import <Foundation/Foundation.h>
#import "HCGRegistry.h"

NS_ASSUME_NONNULL_BEGIN

// HCG System Tester device inventory, schema hcg.systemtester.inventory/1 (HCG-System-Tester
// Sources/HCGCore/Reports/DeviceReport.swift, DeviceInventorySnapshot). System Tester stays the hardware
// communication authority: Nexus only reads a file System Tester exported (redacted by System Tester), never talks to
// a device, and never offers control. Synthetic (fixture) devices are labelled and never count as evidence.

FOUNDATION_EXPORT NSString *const HCGDeviceInventorySchema;     // "hcg.systemtester.inventory/1"
FOUNDATION_EXPORT NSString *const HCGDeviceInventoryStoreKey;   // "systemTesterInventory" (the validated JSON)

@interface HCGInventoryDevice : NSObject {
    NSString *_key;
    NSString *_name;
    NSString *_category;
    NSString *_status;
    NSString *_connection;
    NSString *_intelligenceState;
    NSString *_model;
    NSString *_osVersion;
    NSString *_provenance;
}
@property (nonatomic, copy) NSString *key;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *category;            // DeviceCategory raw value ("unknown" when not recognised)
@property (nonatomic, copy) NSString *status;              // DeviceStatus raw value
@property (nonatomic, copy) NSString *connection;          // ConnectionType raw value
@property (nonatomic, copy, nullable) NSString *intelligenceState;
@property (nonatomic, copy, nullable) NSString *model;
@property (nonatomic, copy, nullable) NSString *osVersion;
@property (nonatomic, copy) NSString *provenance;          // hardware, synthetic, imported
@property (nonatomic, readonly) BOOL synthetic;
@property (nonatomic, readonly) NSString *statusTitle;     // System Tester's own wording
@property (nonatomic, readonly) NSString *connectionTitle;
@end

@interface HCGDeviceInventory : NSObject {
    NSDate *_generatedAt;
    NSString *_installationSuffix;
    NSString *_appVersion;
    NSArray *_devices;
    NSArray *_problems;
}
@property (nonatomic, copy) NSDate *generatedAt;
@property (nonatomic, copy) NSString *installationSuffix;   // last 4 characters of System Tester's installation ID
@property (nonatomic, copy) NSString *appVersion;
@property (nonatomic, copy) NSArray<HCGInventoryDevice *> *devices;
@property (nonatomic, copy) NSArray<NSString *> *problems;

// nil when the file is not a valid inventory; `error` says why. Files over 2 MB or with more than 1000 devices are refused.
+ (nullable instancetype)inventoryWithData:(nullable NSData *)data error:(NSString *_Nullable *_Nullable)error;
// "2026-11-26T10:00:00Z" / with fractional seconds / with an offset.
+ (nullable NSDate *)dateFromISO8601:(nullable NSString *)text;
- (NSArray<HCGInventoryDevice *> *)devicesInClass:(HCGRegistryDeviceClass *)deviceClass;
// Devices in no class (shown under "Other devices").
- (NSArray<HCGInventoryDevice *> *)devicesInNoClassOf:(NSArray<HCGRegistryDeviceClass *> *)classes;
@end

NS_ASSUME_NONNULL_END
