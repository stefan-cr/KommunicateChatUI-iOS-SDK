//
//  FriendCell.swift
//
//
//  Created by Mukesh Thawani on 04/05/17.
//

import Kingfisher
import UIKit

protocol ALKFriendCellProtocol: AnyObject {
    func startVOIPWithFriend(atIndex: IndexPath)
    func startChatWithFriend(atIndex: IndexPath)
    func deleteFriend(atIndex: IndexPath)
}

class ALKFriendCell: UITableViewCell {
    @IBOutlet var imgDisplay: UIImageView!
    @IBOutlet var lblDisplayName: UILabel!

    var delegateFriendCell: ALKFriendCellProtocol!
    var indexPath: IndexPath!

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
        setupUI()
    }

    // MARK: - UI control

    func setupUI() {
        imgDisplay.layer.cornerRadius = 0.5 * imgDisplay.bounds.size.width
        imgDisplay.clipsToBounds = true

        lblDisplayName.textColor = .text(.black00)
    }

    func update(friend: ALKIdentityProtocol) {
        // no actual data yet
        lblDisplayName.text = friend.displayName

        if friend.displayName == "Create Group" {
            imgDisplay.image = UIImage(named: "group_profile_picture", in: Bundle.km, compatibleWith: nil)
            return
        }

        // image
        let placeHolder = UIImage(named: "placeholder", in: Bundle.km, compatibleWith: nil)
        if let tempURL: URL = friend.displayPhoto {
            let resource = KF.ImageResource(downloadURL: tempURL)
            imgDisplay.kf.setImage(with: resource, placeholder: placeHolder)

        } else {
            imgDisplay.image = placeHolder
        }
    }

    @IBAction func voipPress(_: Any) {
        delegateFriendCell.startVOIPWithFriend(atIndex: indexPath)
    }

    @IBAction func chatPress(_: Any) {
        delegateFriendCell.startChatWithFriend(atIndex: indexPath)
    }
}
