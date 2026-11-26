#import "HCGDeviceInventory.h"
#include <time.h>

NSString *const HCGDeviceInventorySchema = @"hcg.systemtester.inventory/1";
NSString *const HCGDeviceInventoryStoreKey = @"systemTesterInventory";

static NSString *Text(id value, NSUInteger limit) {
    if (![value isKindOfClass:[NSString class]]) return nil;
    NSString *s = [value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (!s.length) return nil;
    return s.length > limit ? [s substringToIndex:limit] : s;
}

static NSString *TitleFrom(NSString *raw, NSString *pairs) {
    // pairs: "raw=Title|raw=Title"
    for (NSString *pair in [pairs componentsSeparatedByString:@"|"]) {
        NSRange eq = [pair rangeOfString:@"="];
        if (eq.location != NSNotFound && [[pair substringToIndex:eq.location] isEqualToString:raw]) return [pair substringFromIndex:eq.location + 1];
    }
    return raw;
}

static NSString *const kCategories = @"playStation xbox nintendo smartphone tablet computer server smartRefrigerator smartTelevision smartHome networkEquipment microcontroller robotics storage camera audio industrial gamingAccessory inputDevice usbInfrastructure unknown";
static NSString *const kStatuses = @"detected=Detected|identified=Identified|diagnosticsAvailable=Diagnostics available|adapterRequired=Adapter required|unsupported=Unsupported|connected=Connected|authenticated=Authenticated|disconnected=Disconnected";
static NSString *const kConnections = @"usb=USB / USB-C|usbSerial=USB Serial|hid=HID|thunderbolt=Thunderbolt|ethernet=Ethernet|bluetooth=Bluetooth|localNetwork=Local Network|remoteAuthenticated=Authenticated Remote|manufacturerAPI=Manufacturer API|synthetic=Synthetic Fixture";

static BOOL Known(NSString *raw, NSString *pairs) {
    return [pairs rangeOfString:[raw stringByAppendingString:@"="]].location != NSNotFound;
}

@implementation HCGInventoryDevice
@synthesize key = _key, name = _name, category = _category, status = _status, connection = _connection,
            intelligenceState = _intelligenceState, model = _model, osVersion = _osVersion, provenance = _provenance;

- (BOOL)synthetic {
    return ![self.provenance isEqualToString:@"hardware"] && ![self.provenance isEqualToString:@"imported"];
}

- (NSString *)statusTitle {
    return TitleFrom(self.status, kStatuses);
}

- (NSString *)connectionTitle {
    return TitleFrom(self.connection, kConnections);
}
@end

@implementation HCGDeviceInventory
@synthesize generatedAt = _generatedAt, installationSuffix = _installationSuffix, appVersion = _appVersion, devices = _devices, problems = _problems;

+ (NSDate *)dateFromISO8601:(NSString *)text {
    if (![text isKindOfClass:[NSString class]] || text.length < 19 || text.length > 40) return nil;
    const char *s = [text UTF8String];
    int y, mo, d, h, mi, sec;
    if (sscanf(s, "%4d-%2d-%2dT%2d:%2d:%2d", &y, &mo, &d, &h, &mi, &sec) != 6) return nil;
    if (mo < 1 || mo > 12 || d < 1 || d > 31 || h > 23 || mi > 59 || sec > 60 || y < 2000 || y > 2200) return nil;
    const char *rest = s + 19;
    if (*rest == '.') { rest++; while (*rest >= '0' && *rest <= '9') rest++; }
    long offset = 0;
    if (*rest == 'Z' && rest[1] == 0) offset = 0;
    else if ((*rest == '+' || *rest == '-') && strlen(rest) == 6 && rest[3] == ':') {
        int oh = 0, om = 0;
        if (sscanf(rest + 1, "%2d:%2d", &oh, &om) != 2) return nil;
        offset = (oh * 3600L + om * 60L) * (*rest == '-' ? -1 : 1);
    } else return nil;
    struct tm t;
    memset(&t, 0, sizeof(t));
    t.tm_year = y - 1900;
    t.tm_mon = mo - 1;
    t.tm_mday = d;
    t.tm_hour = h;
    t.tm_min = mi;
    t.tm_sec = sec;
    return [NSDate dateWithTimeIntervalSince1970:(double)timegm(&t) - offset];
}

+ (instancetype)inventoryWithData:(NSData *)data error:(NSString **)error {
    if (!data.length || data.length > 2 * 1024 * 1024) {
        if (error) *error = data.length ? @"The file is larger than 2 MB." : @"The file is empty.";
        return nil;
    }
    id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
    if (![json isKindOfClass:[NSDictionary class]] || ![[json objectForKey:@"schema"] isEqual:HCGDeviceInventorySchema]) {
        if (error) *error = @"Not an HCG System Tester device inventory (hcg.systemtester.inventory/1).";
        return nil;
    }
    NSDate *generated = [self dateFromISO8601:[json objectForKey:@"generatedAt"]];
    NSString *installation = Text([json objectForKey:@"installationID"], 80), *version = Text([json objectForKey:@"appVersion"], 40);
    id list = [json objectForKey:@"devices"];
    if (!generated || !installation || !version || ![list isKindOfClass:[NSArray class]]) {
        if (error) *error = @"The inventory is missing generatedAt, installationID, appVersion or devices.";
        return nil;
    }
    if ([list count] > 1000) {
        if (error) *error = @"The inventory lists more than 1000 devices.";
        return nil;
    }
    NSMutableArray *devices = [NSMutableArray array], *problems = [NSMutableArray array];
    NSArray *categories = [kCategories componentsSeparatedByString:@" "];
    for (id item in list) {
        if (![item isKindOfClass:[NSDictionary class]]) continue;
        NSString *key = Text([item objectForKey:@"key"], 120), *name = Text([item objectForKey:@"name"], 120);
        NSString *category = Text([item objectForKey:@"category"], 40), *status = Text([item objectForKey:@"status"], 40);
        NSString *connection = Text([item objectForKey:@"connection"], 40), *provenance = Text([item objectForKey:@"provenance"], 20);
        if (!key || !name || !category || !status || !connection || !provenance) {
            [problems addObject:@"A device record without its required fields was skipped."];
            continue;
        }
        HCGInventoryDevice *d = [[HCGInventoryDevice alloc] init];
        d.key = key;
        d.name = name;
        d.category = [categories containsObject:category] ? category : @"unknown";
        d.status = Known(status, kStatuses) ? status : @"detected";
        d.connection = Known(connection, kConnections) ? connection : @"usb";
        if (![d.category isEqualToString:category] || ![d.status isEqualToString:status] || ![d.connection isEqualToString:connection]) {
            [problems addObject:[NSString stringWithFormat:@"%@: a value this version does not know was shown as unknown.", name]];
        }
        d.provenance = [[NSArray arrayWithObjects:@"hardware", @"synthetic", @"imported", nil] containsObject:provenance] ? provenance : @"synthetic";
        d.intelligenceState = Text([item objectForKey:@"intelligenceState"], 40);
        d.model = Text([item objectForKey:@"model"], 80);
        d.osVersion = Text([item objectForKey:@"osVersion"], 40);
        [devices addObject:d];
    }
    HCGDeviceInventory *inv = [[HCGDeviceInventory alloc] init];
    inv.generatedAt = generated;
    inv.installationSuffix = installation.length > 4 ? [installation substringFromIndex:installation.length - 4] : installation;
    inv.appVersion = version;
    inv.devices = devices;
    inv.problems = problems;
    return inv;
}

- (NSArray *)devicesInClass:(HCGRegistryDeviceClass *)deviceClass {
    NSMutableArray *out = [NSMutableArray array];
    for (HCGInventoryDevice *d in self.devices) if ([deviceClass.systemTesterCategories containsObject:d.category]) [out addObject:d];
    return out;
}

- (NSArray *)devicesInNoClassOf:(NSArray *)classes {
    NSMutableArray *out = [NSMutableArray array];
    for (HCGInventoryDevice *d in self.devices) {
        BOOL found = NO;
        for (HCGRegistryDeviceClass *c in classes) if ([c.systemTesterCategories containsObject:d.category]) found = YES;
        if (!found) [out addObject:d];
    }
    return out;
}
@end
