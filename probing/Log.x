/* How to Hook with Logos
Hooks are written with syntax similar to that of an Objective-C @implementation.
You don't need to #include <substrate.h>, it will be done automatically, as will
the generation of a class list and an automatic constructor.

%hook ClassName

// Hooking a class method
+ (id)sharedInstance {
	return %orig;
}

// Hooking an instance method with an argument.
- (void)messageName:(int)argument {
	%log; // Write a message about this call, including its class, name and arguments, to the system log.

	%orig; // Call through to the original function with its original arguments.
	%orig(nil); // Call through to the original function with a custom argument.

	// If you use %orig(), you MUST supply all arguments (except for self and _cmd, the automatically generated ones.)
}

// Hooking an instance method with no arguments.
- (id)noArguments {
	%log;
	id awesome = %orig;
	[awesome doSomethingElse];

	return awesome;
}

// Always make sure you clean up after yourself; Not doing so could have grave consequences!
%end
*/



#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <mach-o/dyld.h>

static void IGDumpMethods(FILE *f, Class cls, char kind) {
    unsigned int n = 0;
    Method *list = class_copyMethodList(cls, &n);
    for (unsigned int i = 0; i < n; i++) {
        fprintf(f, "%s %c %s\t%s\n", class_getName(cls), kind,
                sel_getName(method_getName(list[i])),
                method_getTypeEncoding(list[i]) ?: "");
    }
    free(list);
}

static NSString *IGRuntimeDump(void) {
    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:@"ig_methods.txt"];
    FILE *f = fopen(path.fileSystemRepresentation, "w");
    if (!f) return nil;

    // Only Instagram's own binaries, not Apple's frameworks
    NSString *needle = [NSString stringWithFormat:@"/%@/", NSBundle.mainBundle.bundlePath.lastPathComponent];
    for (uint32_t i = 0; i < _dyld_image_count(); i++) {
        const char *img = _dyld_get_image_name(i);
        if (!img || !strstr(img, needle.UTF8String)) continue;
        const char *mod = strrchr(img, '/'); mod = mod ? mod + 1 : img;

        unsigned int count = 0;
        const char **names = objc_copyClassNamesForImage(img, &count);
        for (unsigned int j = 0; j < count; j++) {
            Class cls = objc_getClass(names[j]);
            if (!cls) continue;
            Class sup = class_getSuperclass(cls);
            fprintf(f, "@ %s : %s  [%s]\n", names[j], sup ? class_getName(sup) : "-", mod);
            IGDumpMethods(f, object_getClass(cls), '+'); // class methods
            IGDumpMethods(f, cls, '-');                  // instance methods
        }
        free(names);
    }
    fclose(f);
    return path;
}

// Runs once, a few seconds after Reels first appears (so its code is loaded)
%hook IGSundialFeedViewController
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        UIViewController *vc = (UIViewController *)self;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC),
                       dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
            NSString *path = IGRuntimeDump();
            dispatch_async(dispatch_get_main_queue(), ^{
                if (!path) return;
                UIActivityViewController *share = [[UIActivityViewController alloc]
                    initWithActivityItems:@[[NSURL fileURLWithPath:path]] applicationActivities:nil];
                share.popoverPresentationController.sourceView = vc.view;
                [vc presentViewController:share animated:YES completion:nil];
            });
        });
    });
}
%end