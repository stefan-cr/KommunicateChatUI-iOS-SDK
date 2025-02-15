//
//  ALKCreateGroupViewController.swift
//  KommunicateChatUI-iOS-SDK
//
//  Created by Mukesh Thawani on 04/05/17.
//

import Kingfisher
import KommunicateCore_iOS_SDK
import UIKit

protocol ALKCreateGroupChatAddFriendProtocol: AnyObject {
    func createGroupGetFriendInGroupList(
        friendsSelected: [ALKFriendViewModel],
        groupName: String,
        groupImgUrl: String?,
        friendsAdded: [ALKFriendViewModel],
        groupDescription: String?
    )
}

final class ALKCreateGroupViewController: ALKBaseViewController, Localizable {
    enum ALKAddContactMode: Localizable {
        case newChat
        case existingChat

        func navigationBarTitle(localizedStringFileName: String) -> String {
            switch self {
            case .newChat:
                return localizedString(forKey: "CreateGroupTitle", withDefaultValue: SystemMessage.NavbarTitle.createGroupTitle, fileName: localizedStringFileName)
            default:
                return localizedString(forKey: "EditGroupTitle", withDefaultValue: SystemMessage.NavbarTitle.editGroupTitle, fileName: localizedStringFileName)
            }
        }

        func doneButtonTitle(localizedStringFileName: String) -> String {
            return localizedString(forKey: "SaveButtonTitle", withDefaultValue: SystemMessage.ButtonName.Save, fileName: localizedStringFileName)
        }
    }

    enum GroupNameEditString: Localizable {
        case alert
        func okButtonTitle(localizedStringFileName: String) -> String {
            return localizedString(forKey: "OkMessage", withDefaultValue: SystemMessage.ButtonName.ok, fileName: localizedStringFileName)
        }

        func fillGroupNameTitle(localizedStringFileName: String) -> String {
            return localizedString(forKey: "FillGroupName", withDefaultValue: SystemMessage.Warning.FillGroupName, fileName: localizedStringFileName)
        }
    }

    enum CollectionViewSection {
        static let groupDescription = 0
        static let addMemeber = 1
        static let participants = 2
    }

    let cellId = "GroupMemberCell"

    var groupList = [ALKFriendViewModel]()
    var addedList = [ALKFriendViewModel]()
    var addContactMode: ALKAddContactMode = .newChat
    var groupDescriptionText: String?

    /// To be passed from outside for existing chat
    weak var groupDelegate: ALKCreateGroupChatAddFriendProtocol?
    private var groupName: String = ""
    var groupProfileImgUrl = ""
    var groupId: NSNumber = 0

    @IBOutlet var participantsLabel: UILabel!
    @IBOutlet var editLabel: UILabel!
    @IBOutlet fileprivate var btnCreateGroup: UIButton!
    @IBOutlet fileprivate var tblParticipants: UICollectionView!
    @IBOutlet fileprivate var txtfGroupName: ALKGroupChatTextField!

    @IBOutlet fileprivate var viewGroupImg: UIView!
    @IBOutlet fileprivate var imgGroupProfile: UIImageView!
    fileprivate var tempSelectedImg: UIImage!
    fileprivate var cropedImage: UIImage?

    fileprivate let activityIndicator = UIActivityIndicatorView(style: UIActivityIndicatorView.Style.gray)

    fileprivate lazy var localizedStringFileName: String = configuration.localizedStringFileName

    var viewModel: ALKCreateGroupViewModel!

    private var createGroupBGColor: UIColor {
        return btnCreateGroup.isEnabled ? configuration.channelDetail.button.background : UIColor.disabledButton()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        tblParticipants.register(ALKGroupMemberCell.self)
        tblParticipants.register(ALKGroupDescriptionCell.self)
        tblParticipants.register(ALKGroupHeaderTitleCell.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: ALKGroupHeaderTitleCell.cellID)

        tblParticipants.showsVerticalScrollIndicator = false
        viewModel = ALKCreateGroupViewModel(
            groupName: groupName,
            groupId: groupId,
            delegate: self,
            localizationFileName: localizedStringFileName,
            shouldShowInfoOption: configuration.showInfoOptionInGroupDetail
        )
        viewModel.fetchParticipants()
        setupUI()
        hideKeyboard()
    }

    override func addObserver() {
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name(rawValue: "Updated_Group_Members"),
            object: nil,
            queue: nil,
            using: {
                [weak self] notification in
                    guard
                        let weakSelf = self,
                        let channel = notification.object as? ALChannel,
                        channel.key == weakSelf.groupId
                    else {
                        return
                    }
                    weakSelf.viewModel?.fetchParticipants()
            }
        )
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        txtfGroupName.resignFirstResponder()
        // self.hideKeyboard()
    }

    // MARK: - UI controller

    @IBAction func dismisssPress(_: Any) {
        _ = navigationController?.popViewController(animated: true)
    }

    @IBAction func createGroupPress(_: Any) {
        guard var groupName = txtfGroupName.text?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            let msg = localizedString(forKey: "FillGroupName", withDefaultValue: SystemMessage.Warning.FillGroupName, fileName: localizedStringFileName)
            alert(msg: msg)
            return
        }

        if groupName.lengthOfBytes(using: .utf8) < 1 {
            let msg = localizedString(forKey: "FillGroupName", withDefaultValue: SystemMessage.Warning.FillGroupName, fileName: localizedStringFileName)
            alert(msg: msg)
            return
        }

        groupName = self.groupName == groupName ? "" : groupName

        if groupDelegate != nil {
            if let image = cropedImage {
                // upload image first
                guard let uploadUrl = URL(string: ALUserDefaultsHandler.getBASEURL() + AL_IMAGE_UPLOAD_URL) else {
                    NSLog("NO URL TO UPLOAD GROUP PROFILE IMAGE")
                    return
                }
                let downloadManager = ALKHTTPManager()
                activityIndicator.isHidden = false
                activityIndicator.startAnimating()
                btnCreateGroup.isEnabled = false
                downloadManager.upload(image: image, uploadURL: uploadUrl, completion: {
                    imageUrlData in
                    DispatchQueue.main.async {
                        self.activityIndicator.stopAnimating()
                        self.activityIndicator.isHidden = true
                        self.btnCreateGroup.isEnabled = true
                    }
                    guard let data = imageUrlData, let imageUrl = String(data: data, encoding: .utf8) else {
                        NSLog("GROUP PROFILE PICTURE UPDATE FAILED")
                        return
                    }
                    // Pass groupName empty in case of group name update
                    DispatchQueue.main.async {
                        self.groupDelegate?.createGroupGetFriendInGroupList(friendsSelected: self.groupList, groupName: groupName, groupImgUrl: imageUrl, friendsAdded: self.addedList, groupDescription: self.groupDescriptionText)
                    }
                })
            } else {
                // Pass groupImgUrl empty in case of group name update
                groupDelegate?.createGroupGetFriendInGroupList(friendsSelected: groupList, groupName: groupName, groupImgUrl: nil, friendsAdded: addedList, groupDescription: groupDescriptionText)
            }
        }
    }

    fileprivate func setupUI() {
        // Textfield Group name
        if UIApplication.sharedUIApplication()?.userInterfaceLayoutDirection == .rightToLeft {
            txtfGroupName.textAlignment = .right
        }
        activityIndicator.center = CGPoint(x: view.bounds.size.width / 2, y: view.bounds.size.height / 2)
        activityIndicator.color = UIColor.lightGray
        view.addSubview(activityIndicator)
        activityIndicator.isHidden = true
        txtfGroupName.layer.cornerRadius = 10
        txtfGroupName.layer.borderColor = configuration.channelDetail.groupNameBorderColor.cgColor
        txtfGroupName.layer.borderWidth = 1
        txtfGroupName.clipsToBounds = true
        txtfGroupName.delegate = self
        txtfGroupName.textColor = configuration.channelDetail.groupName.text
        txtfGroupName.font = configuration.channelDetail.groupName.font
        setupAttributedPlaceholder(textField: txtfGroupName)

        // set btns into circle
        viewGroupImg.layer.cornerRadius = 0.5 * viewGroupImg.frame.size.width
        viewGroupImg.clipsToBounds = true

        editLabel.textColor = configuration.channelDetail.editLabel.text
        editLabel.backgroundColor = configuration.channelDetail.editLabel.background

        editLabel.text = localizedString(forKey: "Edit", withDefaultValue: SystemMessage.LabelName.Edit, fileName: localizedStringFileName)

        btnCreateGroup.setFont(font: configuration.channelDetail.button.font)
        btnCreateGroup.setTextColor(color: configuration.channelDetail.button.text, forState: .normal)
        if addContactMode == .existingChat {
            // Button Create Group
            btnCreateGroup.layer.cornerRadius = 15
            btnCreateGroup.clipsToBounds = true
            btnCreateGroup.setTitle(addContactMode.doneButtonTitle(localizedStringFileName: localizedStringFileName), for: UIControl.State.normal)
        } else {
            btnCreateGroup.isHidden = true
        }

        txtfGroupName.text = groupName

        updateCreateGroupButtonUI(contactInGroup: groupList.count,
                                  groupname: txtfGroupName.trimmedWhitespaceText())

        tblParticipants.reloadData()
        title = addContactMode.navigationBarTitle(localizedStringFileName: localizedStringFileName)

        let placeHolder = configuration.channelDetail.defaultGroupIcon?.scale(with: CGSize(width: 25, height: 25))

        if let url = URL(string: groupProfileImgUrl) {
            let resource = KF.ImageResource(downloadURL: url, cacheKey: groupProfileImgUrl)
            imgGroupProfile.kf.setImage(with: resource, placeholder: placeHolder)
        } else {
            imgGroupProfile.image = placeHolder
        }
    }

    private func setupAttributedPlaceholder(textField: UITextField) {
        let style = NSMutableParagraphStyle()
        style.alignment = .left
        style.lineBreakMode = .byWordWrapping

        guard let font = UIFont(name: "HelveticaNeue-Italic", size: 14) else { return }
        let attr: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key.font: font,
            NSAttributedString.Key(rawValue: NSAttributedString.Key.paragraphStyle.rawValue): style,
            NSAttributedString.Key.foregroundColor: UIColor.placeholderGray(),
        ]

        let typeGroupNameMsg = localizedString(forKey: "TypeGroupName", withDefaultValue: SystemMessage.LabelName.TypeGroupName, fileName: localizedStringFileName)
        textField.attributedPlaceholder = NSAttributedString(string: typeGroupNameMsg, attributes: attr)
    }

    @IBAction private func selectGroupImgPress(_: Any) {
        guard
            let vc = ALKCustomCameraViewController.makeInstanceWith(delegate: self, and: configuration)
        else { return }
        present(vc, animated: true, completion: nil)
    }

    func setCurrentGroupSelected(groupId: NSNumber,
                                 groupProfile: String?,
                                 delegate: ALKCreateGroupChatAddFriendProtocol)
    {
        groupDelegate = delegate
        self.groupId = groupId
        groupName = ALChannelService().getChannelByKey(groupId)?.name ?? ""
        guard let image = groupProfile else { return }
        groupProfileImgUrl = image
    }

    private func isAtLeastOneContact(contactCount _: Int) -> Bool {
        return viewModel.numberOfRows() != 0
    }

    private func changeCreateGroupButtonState(isEnabled: Bool) {
        btnCreateGroup.isEnabled = isEnabled
        btnCreateGroup.backgroundColor = createGroupBGColor
    }

    fileprivate func updateCreateGroupButtonUI(contactInGroup: Int, groupname: String) {
        guard isAtLeastOneContact(contactCount: contactInGroup) else {
            changeCreateGroupButtonState(isEnabled: false)
            return
        }
        guard !groupname.isEmpty else {
            changeCreateGroupButtonState(isEnabled: false)
            return
        }
        changeCreateGroupButtonState(isEnabled: true)
    }

    override func prepare(for segue: UIStoryboardSegue, sender _: Any?) {
        if segue.identifier == "goToSelectFriendToAdd" {
            let selectParticipantViewController = segue.destination as? ALKParticipantSelectionViewContoller
            selectParticipantViewController?.selectParticipantDelegate = self
            selectParticipantViewController?.friendsInGroup = viewModel.membersInfo
            selectParticipantViewController?.configuration = configuration
        }
    }

    override func backTapped() {
        guard let createGroupViewModel = viewModel else {
            _ = navigationController?.popViewController(animated: true)
            return
        }
        guard let navigationController = navigationController else { return }

        let cancelTitle = localizedString(forKey: "ButtonCancel", withDefaultValue: SystemMessage.ButtonName.Cancel, fileName: localizedStringFileName)
        let discardTitle = localizedString(forKey: "ButtonDiscard", withDefaultValue: SystemMessage.ButtonName.Discard, fileName: localizedStringFileName)
        let alertTitle = localizedString(forKey: "DiscardChangeTitle", withDefaultValue: SystemMessage.LabelName.DiscardChangeTitle, fileName: localizedStringFileName)
        let alertMessage = localizedString(forKey: "DiscardChangeMessage", withDefaultValue: SystemMessage.Warning.DiscardChange, fileName: localizedStringFileName)

        let nameOrImageChange: () -> Bool = {
            createGroupViewModel.groupName !=
                createGroupViewModel.originalGroupName || self.cropedImage != nil
        }
        let popVC: () -> Void = {
            _ = navigationController.popViewController(animated: true)
        }

        UIAlertController.presentDiscardAlert(
            onPresenter: navigationController,
            alertTitle: alertTitle,
            alertMessage: alertMessage,
            cancelTitle: cancelTitle,
            discardTitle: discardTitle,
            onlyForCondition: nameOrImageChange,
            lastAction: popVC
        )
    }

    private func changeUserRole(at index: Int, _ role: NSNumber) {
        print()
        guard ALDataNetworkConnection.checkDataNetworkAvailable() else {
            let notificationView = ALNotificationView()
            notificationView.noDataConnectionNotificationView()
            return
        }
        let member = viewModel.rowAt(index: index)
        let channelUser = ALChannelUser()
        channelUser.role = role
        channelUser.userId = member.id
        guard let channelUserDictionary = channelUser.dictionary() else {
            return
        }
        let indexPath = IndexPath(row: index, section: CollectionViewSection.participants)
        let cell = tblParticipants.cellForItem(at: indexPath) as? ALKGroupMemberCell
        cell?.channelDetailConfig = configuration.channelDetail
        cell?.showLoading()
        ALChannelService().updateChannel(
            groupId,
            andNewName: nil,
            andImageURL: nil,
            orClientChannelKey: nil,
            isUpdatingMetaData: false,
            metadata: nil,
            orChildKeys: nil,
            orChannelUsers: [channelUserDictionary]
        ) { error in
            guard error == nil else {
                print("Error while making admin \(String(describing: error))")
                return
            }
            self.viewModel.updateRoleAt(index: index)
            self.tblParticipants.performBatchUpdates({
                self.tblParticipants.reloadItems(at: [indexPath])
            }, completion: { _ in
            })
        }
    }
}

extension ALKCreateGroupViewController: ALKCreateGroupViewModelDelegate {
    func info(at index: Int) {
        let member = viewModel.rowAt(index: index)
        let info: [String: Any] =
            ["Id": member.id,
             "Name": member.name,
             "Controller": self]

        NotificationCenter.default.post(name: NSNotification.Name(rawValue: "UserInfoSelected"), object: info)
    }

    func remove(at index: Int) {
        guard ALDataNetworkConnection.checkDataNetworkAvailable() else {
            let notificationView = ALNotificationView()
            notificationView.noDataConnectionNotificationView()
            return
        }
        let member = viewModel.rowAt(index: index)
        let format =
            localizedString(
                forKey: "RemoveFromGroup",
                withDefaultValue: SystemMessage.GroupDetails.RemoveFromGroup,
                fileName: localizedStringFileName
            )
        let message = String(format: format, member.name, groupName)
        let optionMenu = UIAlertController(title: nil, message: message, preferredStyle: .actionSheet)
        let removeButton =
            localizedString(
                forKey: "RemoveButtonName",
                withDefaultValue: SystemMessage.ButtonName.Remove,
                fileName: localizedStringFileName
            )
        let removeAction = UIAlertAction(title: removeButton, style: .destructive, handler: { _ in
            let indexPath = IndexPath(row: index, section: CollectionViewSection.participants)
            let cell = self.tblParticipants.cellForItem(at: indexPath) as? ALKGroupMemberCell
            cell?.channelDetailConfig = self.configuration.channelDetail
            cell?.showLoading()
            ALChannelService().removeMember(fromChannel: member.id, andChannelKey: self.groupId, orClientChannelKey: nil, withCompletion: { error, response in
                guard response != nil, error == nil else {
                    print("Error while removing member from group \(String(describing: error))")
                    return
                }
                self.tblParticipants.performBatchUpdates({
                    self.viewModel.removeAt(index: index)
                    self.tblParticipants.deleteItems(at: [indexPath])
                }, completion: { _ in
                })
            })
        })
        let cancelTitle = localizedString(forKey: "Cancel", withDefaultValue: SystemMessage.LabelName.Cancel, fileName: localizedStringFileName)
        let cancelAction = UIAlertAction(title: cancelTitle, style: .cancel)
        optionMenu.addAction(removeAction)
        optionMenu.addAction(cancelAction)
        present(optionMenu, animated: true, completion: nil)
    }

    func makeAdmin(at index: Int) {
        changeUserRole(at: index, NSNumber(value: ADMIN.rawValue))
    }

    func dismissAdmin(at index: Int) {
        changeUserRole(at: index, NSNumber(value: MEMBER.rawValue))
    }

    func sendMessage(at index: Int) {
        let member = viewModel.rowAt(index: index)
        let conversationViewModel = ALKConversationViewModel(
            contactId: member.id,
            channelKey: nil,
            localizedStringFileName: localizedStringFileName
        )

        let conversationVC = ALKConversationViewController(configuration: configuration, individualLaunch: true)
        conversationVC.viewModel = conversationViewModel
        navigationController?.pushViewController(conversationVC, animated: true)
    }

    func membersFetched() {
        tblParticipants.reloadData()
        updateCreateGroupButtonUI(contactInGroup: groupList.count, groupname: viewModel!.groupName)
    }
}

extension ALKCreateGroupViewController: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func collectionView(_: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        switch indexPath.section {
        case CollectionViewSection.groupDescription:
            guard !configuration.channelDetail.disableGroupDescriptionEdit else {
                return
            }
            showGroupDescriptionViewController()
        case CollectionViewSection.addMemeber:
            guard
                let groupName = txtfGroupName.text?.trimmingCharacters(in: .whitespacesAndNewlines),
                groupName.lengthOfBytes(using: .utf8) > 1
            else {
                showGroupNameEmptyAlertView()
                return
            }

            if configuration.disableAddParticipantButton {
                postNotificationForAddMember()
            } else {
                performSegue(withIdentifier: "goToSelectFriendToAdd", sender: nil)
            }
        case CollectionViewSection.participants:
            guard
                let viewModel = viewModel,
                let options = viewModel.optionsForCell(at: indexPath.row)
            else { return }
            showParticpentsTapActionView(options: options, row: indexPath.row, groupViewModel: viewModel)
        default:
            break
        }
    }

    func numberOfSections(in _: UICollectionView) -> Int {
        return 3
    }

    func collectionView(_: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if section == CollectionViewSection.groupDescription ||
            section == CollectionViewSection.addMemeber
        {
            return 1
        }
        return viewModel.numberOfRows()
    }

    func collectionView(_: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if indexPath.section == CollectionViewSection.groupDescription {
            let cell: ALKGroupDescriptionCell = tblParticipants.dequeueReusableCell(forIndexPath: indexPath)
            let groupViewModel = ALKGroupDescriptionViewModel(channelKey: viewModel.groupId)
            let groupDescription = groupDescriptionText ?? groupViewModel.groupDescription()
            cell.updateView(localizedStringFileName: configuration.localizedStringFileName, descriptionText: groupDescription, channelDetailConfig: configuration.channelDetail)
            return cell
        } else if indexPath.section == CollectionViewSection.addMemeber {
            let cell: ALKGroupMemberCell = tblParticipants.dequeueReusableCell(forIndexPath: indexPath)
            cell.channelDetailConfig = configuration.channelDetail
            let addParticipantText = localizedString(
                forKey: "AddParticipant",
                withDefaultValue: SystemMessage.GroupDetails.AddParticipant,
                fileName: localizedStringFileName
            )
            cell.updateView(model: GroupMemberInfo(name: addParticipantText))
            return cell
        } else {
            let cell: ALKGroupMemberCell = tblParticipants.dequeueReusableCell(forIndexPath: indexPath)
            cell.channelDetailConfig = configuration.channelDetail
            guard let viewModel = viewModel else { return cell }
            let member = viewModel.rowAt(index: indexPath.row)
            cell.updateView(model: member)
            return cell
        }
    }

    func collectionView(_: UICollectionView, layout _: UICollectionViewLayout, sizeForItemAt path: IndexPath) -> CGSize {
        if path.section == CollectionViewSection.groupDescription {
            let groupViewModel = ALKGroupDescriptionViewModel(channelKey: viewModel.groupId)
            let groupDescription = groupDescriptionText ?? groupViewModel.groupDescription()
            let height = ALKGroupDescriptionCell.rowHeight(descrption: groupDescription, maxWidth: view.frame.width)
            return CGSize(width: view.frame.width - ALKGroupDescriptionCell.Padding.DescriptionLabel.left + ALKGroupDescriptionCell.Padding.DescriptionLabel.right, height: height)
        }
        return cellHeight()
    }

    func collectionView(_: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        guard kind == UICollectionView.elementKindSectionHeader else {
            return UICollectionReusableView()
        }

        if indexPath.section == CollectionViewSection.groupDescription {
            let header = tblParticipants.dequeueReusableSupplementaryView(
                ofKind: UICollectionView.elementKindSectionHeader,
                withReuseIdentifier: ALKGroupHeaderTitleCell.cellID,
                for: indexPath
            ) as! ALKGroupHeaderTitleCell

            let groupDescriptionHeaderTitle = localizedString(forKey: "GroupDescriptionHeaderTitle", withDefaultValue: SystemMessage.LabelName.GroupDescription, fileName: localizedStringFileName)

            header.updateView(titleText: groupDescriptionHeaderTitle,
                              localizedStringFileName: configuration.localizedStringFileName,
                              channelDetailConfig: configuration.channelDetail)
            return header
        } else if indexPath.section == CollectionViewSection.addMemeber {
            let header = tblParticipants.dequeueReusableSupplementaryView(
                ofKind: UICollectionView.elementKindSectionHeader,
                withReuseIdentifier: "ALKGroupHeaderTitleCell",
                for: indexPath
            ) as! ALKGroupHeaderTitleCell

            let participantHeaderTitle = localizedString(forKey: "Participants", withDefaultValue: SystemMessage.LabelName.Participants, fileName: localizedStringFileName)

            header.updateView(titleText: participantHeaderTitle,
                              localizedStringFileName: configuration.localizedStringFileName,
                              channelDetailConfig: configuration.channelDetail)
            return header
        }
        return UICollectionReusableView()
    }

    func postNotificationForAddMember() {
        var dic = [AnyHashable: Any]()
        dic["ChannelKey"] = groupId
        dic["Controller"] = self
        dic["AddMember"] = true
        NotificationCenter.default.post(name: Notification.Name(rawValue: ALKNotification.createGroupAction), object: self, userInfo: dic)
    }

    public func collectionView(_: UICollectionView, layout _: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        if section == CollectionViewSection.groupDescription {
            let widthPadding = ALKGroupHeaderTitleCell.Padding.HeaderTitleLabel.left + ALKGroupHeaderTitleCell.Padding.HeaderTitleLabel.right

            let groupDescriptionHeaderTitle = localizedString(forKey: "GroupDescriptionHeaderTitle", withDefaultValue: SystemMessage.LabelName.GroupDescription, fileName: localizedStringFileName)

            let height = ALKGroupHeaderTitleCell.rowHeight(descrption: groupDescriptionHeaderTitle, maxWidth: view.frame.width - widthPadding, font: configuration.channelDetail.participantHeaderTitle.font)
            return CGSize(width: view.frame.width - widthPadding, height: height)
        } else if section == CollectionViewSection.addMemeber {
            guard let viewModel = viewModel, viewModel.isAddAllowed else {
                return CGSize(width: 0, height: 0)
            }
            return cellHeight()
        }
        return CGSize(width: 0, height: 0)
    }

    private func cellHeight() -> CGSize {
        let height = ALKGroupMemberCell.rowHeight()
        if #available(iOS 11.0, *) {
            let safeAreaInsets = self.view.safeAreaInsets
            return CGSize(width: UIScreen.main.bounds.width - (safeAreaInsets.left + safeAreaInsets.right), height: height)
        } else {
            // Fallback on earlier versions
            return CGSize(width: UIScreen.main.bounds.width, height: height)
        }
    }

    private func showGroupNameEmptyAlertView() {
        let alert = UIAlertController(title: nil, message: GroupNameEditString.alert.fillGroupNameTitle(localizedStringFileName: localizedStringFileName), preferredStyle: .alert)
        let action = UIAlertAction(title: GroupNameEditString.alert.okButtonTitle(localizedStringFileName: localizedStringFileName), style: .default, handler: nil)
        alert.addAction(action)
        present(alert, animated: true, completion: nil)
    }

    private func showGroupDescriptionViewController() {
        let groupDescriptionVC = ALKGroupDescriptionController(channelKey: viewModel.groupId, configuration: configuration, isFromGroupCreate: addContactMode == .newChat)
        if addContactMode == .newChat {
            groupDescriptionVC.delegate = self
        }
        navigationController?.pushViewController(groupDescriptionVC, animated: true)
    }

    func showParticpentsTapActionView(options: [Options],
                                      row: Int,
                                      groupViewModel: ALKCreateGroupViewModel)
    {
        let memberInfo = groupViewModel.rowAt(index: row)
        let optionMenu = UIAlertController(title: nil, message: memberInfo.name, preferredStyle: .actionSheet)
        options.forEach {
            optionMenu.addAction($0.value(localizationFileName: localizedStringFileName, index: row, delegate: self))
        }
        present(optionMenu, animated: true, completion: nil)
    }
}

extension ALKCreateGroupViewController: ALKAddParticipantProtocol {
    func addParticipantAtIndex(atIndex: IndexPath) {
        if atIndex.row == groupList.count || groupList.isEmpty {
            txtfGroupName.resignFirstResponder()
            if configuration.disableAddParticipantButton {
                postNotificationForAddMember()
            } else {
                performSegue(withIdentifier: "goToSelectFriendToAdd", sender: nil)
            }
        }
    }

    func profileTappedAt(index: IndexPath) {
        guard addContactMode == .existingChat,
              index.row < groupList.count else { return }
        let user = groupList[index.row]
        let viewModel = ALKConversationViewModel(
            contactId: user.friendUUID,
            channelKey: nil,
            localizedStringFileName: localizedStringFileName
        )

        let conversationVC = ALKConversationViewController(configuration: configuration, individualLaunch: true)
        conversationVC.viewModel = viewModel
        navigationController?.pushViewController(conversationVC, animated: true)
    }
}

extension ALKCreateGroupViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_: UITextField) -> Bool {
        txtfGroupName?.resignFirstResponder()
        return true
    }

    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        let str = textField.text as NSString?
        if let text = str?.replacingCharacters(in: range, with: string) {
            updateCreateGroupButtonUI(contactInGroup: groupList.count, groupname: text)

            guard let viewModel = viewModel else { return true }

            let oldStatus = viewModel.isAddParticipantButtonEnabled()

            viewModel.groupName = text.trimmingCharacters(in: .whitespacesAndNewlines)

            let newStatus = viewModel.isAddParticipantButtonEnabled()
            if oldStatus != newStatus {
                tblParticipants.reloadData()
            }
        }
        return true
    }
}

extension ALKCreateGroupViewController: ALKSelectParticipantToAddProtocol {
    func selectedParticipant(selectedList: [ALKFriendViewModel], addedList: [ALKFriendViewModel]) {
        groupList = selectedList
        self.addedList = addedList
        createGroupPress(btnCreateGroup as Any)
    }
}

extension ALKCreateGroupViewController {
    override func hideKeyboard() {
        let tap = UITapGestureRecognizer(
            target: self,
            action: #selector(ALKCreateGroupViewController.dismissKeyboard)
        )
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }

    override func dismissKeyboard() {
        txtfGroupName.resignFirstResponder()
        view.endEditing(true)
    }
}

extension ALKCreateGroupViewController: ALKCustomCameraProtocol {
    func customCameraDidTakePicture(cropedImage: UIImage) {
        // Be back from cropiing camera page
        tempSelectedImg = imgGroupProfile.image
        imgGroupProfile.image = cropedImage
        self.cropedImage = cropedImage
    }
}

extension ALKCreateGroupViewController: ALKGroupDescriptionDelegate {
    func onGroupDescriptionSave(description: String) {
        groupDescriptionText = description
        tblParticipants.performBatchUpdates({
            let indexSet = IndexSet(integer: CollectionViewSection.groupDescription)
            self.tblParticipants.reloadSections(indexSet)
        }, completion: nil)
    }
}
