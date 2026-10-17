# Objective-C classes in Android File Transfer (main binary)

Recovered with `rea inspect-native-dispatch-metadata`.

## MTPViewerAppDelegate : NSObject
protocols: MTPOutlineControllerDelegate, FirstRunWindowControllerDelegate
ivars: fileMenu_ (@"NSMenu"); goMenu_ (@"NSMenu"); windowMenu_ (@"NSMenu"); helpMenu_ (@"NSMenu"); servicesMenu_ (@"NSMenu"); openWindows_ (@"NSMutableDictionary"); breakpad_ (^v); firstRunWindowController_ (@"FirstRunWindowController"); noDevicesPanel_ (@"NSPanel")
methods:
   -registerDistributedNotificationCenter @ 0x100001bc6
   -awakeFromNib @ 0x100001c68
   -dealloc @ 0x100001f03
   -createWindows @ 0x100001f86
   -firstRunWindowControllerWindowWillClose: @ 0x1000022b3
   -applicationDidFinishLaunching: @ 0x1000022d4
   -applicationShouldTerminateAfterLastWindowClosed: @ 0x1000022e7
   -applicationShouldTerminate: @ 0x1000022f2
   -registerWithKeystone @ 0x10000230d
   -startBreakpad @ 0x100002499
   -createNewWindowFromAgent: @ 0x10000283d
   -closeOldWindowFromAgent: @ 0x100002938
   -createNewWindow: @ 0x100002a33
   -closeAllWindows @ 0x100002e02
   -closeOldWindow: @ 0x100002f98
   -tweakMenus @ 0x10000304c
   -outlineWillClose: @ 0x100003307
   -registerDefaults @ 0x10000336d
   -showHelp: @ 0x100003451
   -aboutApplicationMenuItemTitle @ 0x1000034f9
   -hideMenuItemTitle @ 0x100003573
   -hideOthersMenuItemTitle @ 0x1000035ed
   -showAllMenuItemTitle @ 0x100003667
   -quitMenuItemTitle @ 0x1000036e1
   -newFolderMenuItemTitle @ 0x10000375b
   -closeWindowMenuItemTitle @ 0x1000037d5
   -deleteMenuItemTitle @ 0x10000384f
   -backMenuItemTitle @ 0x1000038c9
   -forwardMenuItemTitle @ 0x100003943
   -enclosingMenuItemTitle @ 0x1000039bd
   -openMenuItemTitle @ 0x100003a37
   -minimizeMenuItemTitle @ 0x100003ab1
   -zoomMenuItemTitle @ 0x100003b2b
   -bringAllToFrontMenuItemTitle @ 0x100003ba5
   -androidFileTransferHelpMenuItemTitle @ 0x100003c1f
   -.cxx_destruct @ 0x100003c99

## MTPOutlineController : NSWindowController
protocols: RecessedButtonMatrixDelegate, CustomOutlineViewDelegate, NSWindowDelegate, NSOutlineViewDataSource
ivars: outlineView_ (@"NSOutlineView"); forwardBackControl_ (@"NSSegmentedControl"); bottomStatusLabel_ (@"NSTextField"); watermarkView_ (@"NSImageView"); storageMatrix_ (@"RecessedButtonMatrix"); pathStack_ (@"NSMutableArray"); pathStackInsertionPoint_ (Q); repository_ ({auto_ptr<Repository>="_M_ptr"^{Repository}}); deviceInfo_ ({auto_ptr<DeviceInfo>="_M_ptr"^{DeviceInfo}}); root_ (@"MTPOutlineNode"); delegate_ (@"<MTPOutlineControllerDelegate>"); sortDescriptors_ (@"NSArray"); humanSizeTransformer_ (@"NSValueTransformer"); currentStorage_ (I)
methods:
   -initWithRepository: @ 0x100003d40
   -deviceIDForRepository @ 0x10000411c
   -awakeFromNib @ 0x1000041b7
   -outlineView:numberOfChildrenOfItem: @ 0x1000045c5
   -outlineView:isItemExpandable: @ 0x100004659
   -outlineView:child:ofItem: @ 0x1000046d2
   -outlineView:objectValueForTableColumn:byItem: @ 0x100004754
   -outlineView:validateDrop:proposedItem:proposedChildIndex: @ 0x1000048e4
   -outlineView:acceptDrop:item:childIndex: @ 0x100004a48
   -writeItems:toPasteboard: @ 0x100005214
   -outlineView:writeItems:toPasteboard: @ 0x10000568e
   -outlineView:startPromiseFileCopy:dropDestination: @ 0x1000056ed
   -outlineView:namesOfPromisedFilesDroppedAtDestination:forDraggedItems: @ 0x100005bd1
   -outlineView:setObjectValue:forTableColumn:byItem: @ 0x100005dcd
   -outlineView:itemForPersistentObject: @ 0x1000062d4
   -outlineView:persistentObjectForItem: @ 0x1000062f9
   -newFilenameForExistingPath:targetDirectory: @ 0x10000631e
   -copyLocalFile:toDeviceDirectory:statusController: @ 0x1000063d1
   -contentsOfLocalDirectory: @ 0x1000068ee
   -copyLocalFiles:toDeviceDirectory:statusController: @ 0x100006b5f
   -preflightCopyLocalFiles:statusController: @ 0x100007178
   -copyLocalFilesThread: @ 0x100007488
   -criticalError: @ 0x100007641
   -unlockDeviceError: @ 0x1000077ff
   -copyDeviceFile:toLocalDirectory:statusController: @ 0x1000079bd
   -copyDeviceFiles:toLocalDirectory:statusController: @ 0x1000080bb
   -preflightCopyDeviceFiles:statusController: @ 0x100008698
   -copyDeviceFilesThread: @ 0x1000088ed
   -canGoBack @ 0x100008a70
   -canGoForward @ 0x100008a88
   -setCurrentRoot: @ 0x100008ac1
   -setCurrentRootArray: @ 0x100008ade
   -setCurrentRoot:storage: @ 0x100008bc4
   -deletePaths: @ 0x100009178
   -deleteAlertDidEnd:returnCode:contextInfo: @ 0x100009493
   -outlineView:willDisplayCell:forTableColumn:item: @ 0x100009ae8
   -outlineView:shouldEditTableColumn:item: @ 0x100009bf0
   -outlineViewItemDidCollapse: @ 0x100009c83
   -outlineViewItemDidExpand: @ 0x100009c96
   -outlineViewSelectionDidChange: @ 0x100009ca9
   -outlineView:mouseDownInHeaderOfTableColumn: @ 0x100009cbc
   -outlineViewColumnDidResize: @ 0x100009cdf
   -outlineView:didDragTableColumn: @ 0x100009cff
   -outlineView:didClickTableColumn: @ 0x100009d1f
   -outlineView:itemsWereDraggedToTrash: @ 0x100009d3f
   -window:shouldPopUpDocumentPathMenu: @ 0x100009da4
   -window:shouldDragDocumentWithEvent:from:withPasteboard: @ 0x10000a266
   -windowWillClose: @ 0x10000a26e
   -refreshFromNode: @ 0x10000a2be
   -getUniqueDeviceFilename: @ 0x10000a658
   -nodeForPath: @ 0x10000a8ff
   -showModalErrorMessage:statusController:informativeText: @ 0x10000abce
   -updateBottomStatus @ 0x10000ae2c
   -friendlyNameOfNode: @ 0x10000b175
   -deleteSelected: @ 0x10000b21e
   -changePathMenuItem: @ 0x10000b414
   -doubleAction: @ 0x10000b472
   -openNode: @ 0x10000b4da
   -goUp: @ 0x10000b886
   -goBack: @ 0x10000b921
   -goForward: @ 0x10000b9b4
   -forwardBackControlClicked: @ 0x10000ba43
   -createNewFolder: @ 0x10000bacd
   -setSortDescriptors: @ 0x10000bdca
   -matrixButtonPressed: @ 0x10000c0b2
   -deleteMenuItem @ 0x10000c0cf
   -newFolderMenuItem @ 0x10000c149
   -.cxx_destruct @ 0x10000c1fd
   -.cxx_construct @ 0x10000c384
   -delegate @ 0x10000c1bf
   -setDelegate: @ 0x10000c1d8
   -sortDescriptors @ 0x10000c1ec

## ImageAndTextCell : NSTextFieldCell
ivars: _image (@"NSImage")
methods:
   -init @ 0x10000c68b
   -imageRectForBounds: @ 0x10000c6f4
   -titleRectForBounds: @ 0x10000c78c
   -editWithFrame:inView:editor:delegate:event: @ 0x10000c84c
   -selectWithFrame:inView:editor:delegate:start:length: @ 0x10000c97b
   -drawWithFrame:inView: @ 0x10000caa1
   -cellSize @ 0x10000cc96
   -hitTestForEvent:inRect:ofView: @ 0x10000cd0f
   -setUpFieldEditorAttributes: @ 0x10000ceb3
   -.cxx_destruct @ 0x10000cf6e
   -image @ 0x10000cf38
   -setImage: @ 0x10000cf4e

## MTPOutlineNode : NSObject
ivars: loaded_ (c); childrenLoaded_ (c); path_ (@"NSString"); children_ (@"NSMutableArray"); childrenDict_ (@"NSMutableDictionary"); sortDescriptors_ (@"NSArray"); icon_ (@"NSImage"); resource_ ({Resource="_name"{basic_string<char, std::char_traits<char>, std::allocator<char> >="_M_dataplus"{_Alloc_hider="_M_p"*}}"_id"I"_storageId"I"_size"Q"_modificationdate"q"_type"i"_loaded"B}); repository_ (^{Repository=^^?}); storageId_ (I)
methods:
   -initWithPath:repository:storageId:sortDescriptors: @ 0x10000cf81
   -loadChildrenFromDevice @ 0x10000d134
   -loadFromDevice @ 0x10000d3bd
   -reloadFromDevice @ 0x10000d5d2
   -ensureLoaded @ 0x10000d600
   -ensureChildrenLoaded @ 0x10000d632
   -setSortDescriptors: @ 0x10000d664
   -childCount @ 0x10000d80c
   -childAtIndex: @ 0x10000d84f
   -children @ 0x10000d8a1
   -childWithName: @ 0x10000d8dd
   -path @ 0x10000d962
   -isFolder @ 0x10000d977
   -icon @ 0x10000d9a6
   -name @ 0x10000d9d2
   -lastModified @ 0x10000da0f
   -nodeSize @ 0x10000da4f
   -nodeSizeNumber @ 0x10000da85
   -description @ 0x10000daba
   -deepDump @ 0x10000db1d
   -.cxx_destruct @ 0x10000dc67
   -.cxx_construct @ 0x10000dcfd
   -sortDescriptors @ 0x10000dc56
   +nodeWithPath:repository:storageId:sortDescriptors: @ 0x10000d08a

## FileSizeHumanTransformer : NSValueTransformer
methods:
   -transformedValue: @ 0x10000de34
   +load @ 0x10000ddc4
   +transformedValueClass @ 0x10000de1b

## CopyStatusViewController : NSViewController
ivars: files_ (@"NSMutableDictionary"); bytesToCopy_ (@"NSNumber"); fileInProgressBytesCopied_ (@"NSNumber"); filesCompletedBytesCopied_ (q); destination_ (@"NSString"); shouldCancel_ (c); preflightComplete_ (c); replaceAll_ (c); startTime_ (@"NSDate"); pausedTime_ (d); humanSizeTransformer_ (@"NSValueTransformer")
methods:
   -init @ 0x10000e0e0
   -addFile:size: @ 0x10000e281
   -skipFile: @ 0x10000e37f
   -finishedFile: @ 0x10000e781
   -fileSize: @ 0x10000e89c
   -preflightComplete @ 0x10000e8eb
   -setPreflightComplete: @ 0x10000e8fc
   -bytesCopied @ 0x10000e951
   -copying @ 0x10000e9c8
   -topProgressString @ 0x10000ea32
   -timeLeft @ 0x10000ed4a
   -bottomProgressString @ 0x10000f10c
   -cancelButtonPressed: @ 0x10000f29b
   -shouldReplaceFilename: @ 0x10000f2b2
   -showPerFileQuestionFormat:informativeText:defaultButton:alternateButton:otherButton:filename: @ 0x10000f570
   -.cxx_destruct @ 0x10000fa4a
   -bytesToCopy @ 0x10000f946
   -setBytesToCopy: @ 0x10000f95c
   -filesCompletedBytesCopied @ 0x10000f97c
   -setFilesCompletedBytesCopied: @ 0x10000f98d
   -fileInProgressBytesCopied @ 0x10000f99e
   -setFileInProgressBytesCopied: @ 0x10000f9b1
   -shouldCancel @ 0x10000f9d1
   -setShouldCancel: @ 0x10000f9e4
   -destination @ 0x10000f9f4
   -setDestination: @ 0x10000fa07
   -replaceAll @ 0x10000fa27
   -setReplaceAll: @ 0x10000fa3a
   +keyPathsForValuesAffectingBytesCopied @ 0x10000e99c
   +keyPathsForValuesAffectingCopying @ 0x10000ea06
   +keyPathsForValuesAffectingTopProgressString @ 0x10000ed1e
   +keyPathsForValuesAffectingBottomProgressString @ 0x10000f264

## StatusWindowController : NSWindowController
ivars: statusControllers_ (@"NSMutableArray"); modal_ (c)
methods:
   -init @ 0x10000fb1a
   -addCopyStatusForWindow: @ 0x10000fc0c
   -removeStatus: @ 0x10000fdbe
   -arrangeStatusViews @ 0x10000fe58
   -allowMoreOperations @ 0x10001017b
   -windowTitle @ 0x1000101b1
   -.cxx_destruct @ 0x100010217
   +sharedStatusWindowController @ 0x10000fabf

## DashedDateFormatter : NSDateFormatter
methods:
   -stringForObjectValue: @ 0x10001022a

## MTPDeviceID : NSObject
ivars: _vendorID (I); _productID (I); _locationID (I)
methods:
   -initWithVendorID:productID:locationID: @ 0x1000102e5
   -description @ 0x1000103ac
   -initWithDictionary: @ 0x1000103f5
   -formatToDictionary @ 0x100010519
   -vendorID @ 0x100010672
   -productID @ 0x100010682
   -locationID @ 0x100010692

## BundleInstaller : NSObject
methods:
   -bundleName @ 0x1000106a2
   -bundleType @ 0x100010759
   -libraryDestinationPath @ 0x100010810
   -shouldUpdateBundle @ 0x1000108c7
   -didUpdateBundle @ 0x1000108d2
   -installBundle @ 0x1000108d8
   -isVersion:higherThanVersion: @ 0x100010c19
   -installedPath @ 0x100010e35
   -destinationPath @ 0x100010f02
   -findInstalledBundle @ 0x100010fb5
   -removeQuarantineFromDirectory: @ 0x100011018
   -installNewBundle @ 0x1000111e3

## AgentRunner : BundleInstaller
methods:
   -bundleName @ 0x10001159f
   -bundleType @ 0x1000115be
   -libraryDestinationPath @ 0x1000115dd
   -shouldUpdateBundle @ 0x1000115fc
   -registerInLoginItems @ 0x100011692
   +startAgent @ 0x100011416

## Utils : NSObject
methods:
   +updateModifiedDate:toFile: @ 0x100011b15
   +updateCreatedDate:toFile: @ 0x100011c07

## CustomOutlineView : NSOutlineView
ivars: lastDropDestination_ (@"NSURL")
methods:
   -stripeColor @ 0x100011cf9
   -drawStripesInRect: @ 0x100011ed1
   -drawRect: @ 0x100012007
   -draggingEntered: @ 0x10001208c
   -draggingUpdated: @ 0x10001212b
   -namesOfPromisedFilesDroppedAtDestination: @ 0x1000121ca
   -draggedImage:endedAt:operation: @ 0x100012224
   -draggingSourceOperationMaskForLocal: @ 0x1000123c2
   -menu @ 0x1000123cd
   -.cxx_destruct @ 0x100012459

## FirstRunWindowController : NSWindowController
ivars: _delegate (@"<FirstRunWindowControllerDelegate>")
methods:
   -initWithDelegate: @ 0x10001246c
   -windowDidLoad @ 0x1000124db
   -buttonTitle @ 0x1000125b8
   -windowWillClose: @ 0x10001276d
   -welcomeTitleText @ 0x1000127b9
   -welcomeBodyText @ 0x10001281f
   -closeButtonClicked: @ 0x100012885
   -.cxx_destruct @ 0x1000128ef
   -delegate @ 0x1000128c2
   -setDelegate: @ 0x1000128db

## BorderlessWindow : NSWindow
methods:
   -initWithContentRect:styleMask:backing:defer: @ 0x100012900
   -canBecomeKeyWindow @ 0x10001297c

## RecessedButtonMatrix : NSView
ivars: buttons_ (@"NSMutableArray"); identifiers_ (@"NSMutableArray"); delegate_ (@"<RecessedButtonMatrixDelegate>")
methods:
   -awakeFromNib @ 0x100012987
   -performLayout @ 0x100012a0e
   -setFrameSize: @ 0x100012d8c
   -buttonPressed: @ 0x100012dce
   -addButton:identifier: @ 0x10001300a
   -selectButtonWithIdentifier: @ 0x100013230
   -.cxx_destruct @ 0x100013455
   -delegate @ 0x100013428
   -setDelegate: @ 0x100013441

## Protocols
- MTPOutlineControllerDelegate: ['outlineWillClose:', 'closeAllWindows']
- NSObject: ['isEqual:', 'class', 'self', 'performSelector:', 'performSelector:withObject:', 'performSelector:withObject:withObject:', 'isProxy', 'isKindOfClass:', 'isMemberOfClass:', 'conformsToProtocol:', 'respondsToSelector:', 'retain', 'release', 'autorelease', 'retainCount', 'zone', 'hash', 'superclass', 'description']
- FirstRunWindowControllerDelegate: ['firstRunWindowControllerWindowWillClose:']
- RecessedButtonMatrixDelegate: ['matrixButtonPressed:']
- NSControlTextEditingDelegate: []
- NSOutlineViewDelegate: []
- CustomOutlineViewDelegate: ['outlineView:itemsWereDraggedToTrash:', 'outlineView:startPromiseFileCopy:dropDestination:']
- NSWindowDelegate: []
- NSOutlineViewDataSource: []
- __ARCLiteKeyedSubscripting__: ['objectForKeyedSubscript:', 'setObject:forKeyedSubscript:']
- __ARCLiteIndexedSubscripting__: ['objectAtIndexedSubscript:', 'setObject:atIndexedSubscript:']
