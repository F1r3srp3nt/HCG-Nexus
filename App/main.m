#import <UIKit/UIKit.h>
#import "HCGAppDelegate.h"

int main(int argc, char *argv[]) {
    NSString *delegateClassName;
    @autoreleasepool {
        delegateClassName = NSStringFromClass([HCGAppDelegate class]);
    }
    return UIApplicationMain(argc, argv, nil, delegateClassName);
}
