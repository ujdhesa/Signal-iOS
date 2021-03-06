//
//  Copyright (c) 2017 Open Whisper Systems. All rights reserved.
//

#import "OWSAddToContactViewController.h"
#import <SignalMessaging/ContactsViewHelper.h>
#import <SignalMessaging/Environment.h>
#import <SignalMessaging/OWSContactsManager.h>
#import <SignalMessaging/UIUtil.h>

@import ContactsUI;

NS_ASSUME_NONNULL_BEGIN

@interface OWSAddToContactViewController () <ContactEditingDelegate, ContactsViewHelperDelegate>

@property (nonatomic) NSString *recipientId;

@property (nonatomic, readonly) OWSContactsManager *contactsManager;
@property (nonatomic, readonly) ContactsViewHelper *contactsViewHelper;

@end

#pragma mark -

@implementation OWSAddToContactViewController

- (instancetype)init
{
    self = [super init];
    if (!self) {
        return self;
    }

    [self commonInit];

    return self;
}

- (nullable instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (!self) {
        return self;
    }

    [self commonInit];

    return self;
}

- (instancetype)initWithNibName:(nullable NSString *)nibNameOrNil bundle:(nullable NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (!self) {
        return self;
    }

    [self commonInit];

    return self;
}

- (void)commonInit
{
    _contactsManager = [Environment current].contactsManager;
    _contactsViewHelper = [[ContactsViewHelper alloc] initWithDelegate:self];
}

- (void)configureWithRecipientId:(NSString *)recipientId
{
    OWSAssert(recipientId.length > 0);

    _recipientId = recipientId;
}

#pragma mark - ContactEditingDelegate

- (void)didFinishEditingContact
{
    DDLogDebug(@"%@ %s", self.logTag, __PRETTY_FUNCTION__);
    [self dismissViewControllerAnimated:NO
                             completion:^{
                                 [self.navigationController popViewControllerAnimated:YES];
                             }];
}

#pragma mark - CNContactViewControllerDelegate

- (void)contactViewController:(CNContactViewController *)viewController
       didCompleteWithContact:(nullable CNContact *)contact
{
    if (contact) {
        // Saving normally returns you to the "Show Contact" view
        // which we're not interested in, so we skip it here. There is
        // an unfortunate blip of the "Show Contact" view on slower devices.
        DDLogDebug(@"%@ completed editing contact.", self.logTag);
        [self dismissViewControllerAnimated:NO
                                 completion:^{
                                     [self.navigationController popViewControllerAnimated:YES];
                                 }];
    } else {
        DDLogDebug(@"%@ canceled editing contact.", self.logTag);
        [self dismissViewControllerAnimated:YES
                                 completion:^{
                                     [self.navigationController popViewControllerAnimated:YES];
                                 }];
    }
}

#pragma mark - ContactsViewHelperDelegate

- (void)contactsViewHelperDidUpdateContacts
{
    [self updateTableContents];
}

#pragma mark - View Lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.title = NSLocalizedString(@"CONVERSATION_SETTINGS_ADD_TO_EXISTING_CONTACT",
        @"Label for 'new contact' button in conversation settings view.");

    [self updateTableContents];
}

- (nullable NSString *)displayNameForContact:(Contact *)contact
{
    OWSAssert(contact);

    if (contact.fullName.length > 0) {
        return contact.fullName;
    }

    for (NSString *email in contact.emails) {
        if (email.length > 0) {
            return email;
        }
    }
    for (NSString *phoneNumber in contact.userTextPhoneNumbers) {
        if (phoneNumber.length > 0) {
            return phoneNumber;
        }
    }

    return nil;
}

- (void)updateTableContents
{
    OWSTableContents *contents = [OWSTableContents new];
    contents.title = NSLocalizedString(@"CONVERSATION_SETTINGS", @"title for conversation settings screen");

    __weak OWSAddToContactViewController *weakSelf = self;

    OWSTableSection *section = [OWSTableSection new];
    section.headerTitle = NSLocalizedString(
        @"EDIT_GROUP_CONTACTS_SECTION_TITLE", @"a title for the contacts section of the 'new/update group' view.");

    for (Contact *contact in self.contactsViewHelper.contactsManager.allContacts) {
        OWSAssert(contact.cnContact);

        NSString *_Nullable displayName = [self displayNameForContact:contact];
        if (displayName.length < 1) {
            continue;
        }

        [section addItem:[OWSTableItem disclosureItemWithText:displayName
                                                  actionBlock:^{
                                                      [weakSelf presentContactViewControllerForContact:contact];
                                                  }]];
    }
    [contents addSection:section];

    self.contents = contents;
    [self.tableView reloadData];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    // In case we're dismissing a CNContactViewController which requires default system appearance
    [UIUtil applySignalAppearence];
}

#pragma mark - Actions

- (void)presentContactViewControllerForContact:(Contact *)contact
{
    OWSAssert(contact);
    OWSAssert(self.recipientId);

    if (!self.contactsManager.supportsContactEditing) {
        OWSFail(@"%@ Contact editing not supported", self.logTag);
        return;
    }
    [self.contactsViewHelper presentContactViewControllerForRecipientId:self.recipientId
                                                     fromViewController:self
                                                        editImmediately:YES
                                                 addToExistingCnContact:contact.cnContact];
}

@end

NS_ASSUME_NONNULL_END
