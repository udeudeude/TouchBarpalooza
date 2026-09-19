#import <AppKit/AppKit.h>

extern void DFRElementSetControlStripPresenceForIdentifier(NSTouchBarItemIdentifier, BOOL);
extern void DFRSystemModalShowsCloseBoxWhenFrontMost(BOOL);

@interface NSTouchBarItem (PokiSitelenPrivate)
+ (void)addSystemTrayItem:(NSTouchBarItem *)item;
+ (void)removeSystemTrayItem:(NSTouchBarItem *)item;
@end

@interface NSTouchBar (PokiSitelenPrivate)
+ (void)presentSystemModalTouchBar:(NSTouchBar *)touchBar
          systemTrayItemIdentifier:(NSTouchBarItemIdentifier)identifier;
+ (void)presentSystemModalTouchBar:(NSTouchBar *)touchBar
                         placement:(long long)placement
          systemTrayItemIdentifier:(NSTouchBarItemIdentifier)identifier;
+ (void)dismissSystemModalTouchBar:(NSTouchBar *)touchBar;
+ (void)minimizeSystemModalTouchBar:(NSTouchBar *)touchBar;
@end
