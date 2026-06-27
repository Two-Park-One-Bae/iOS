import UIKit

public enum DSIcon: String {

    // MARK: - Navigation

    case house = "Icons/ic_house"
    case search = "Icons/ic_search"
    case compass = "Icons/ic_compass"
    case settings = "Icons/ic_settings"
    case arrowLeft = "Icons/ic_arrow_left"
    case chevronLeft = "Icons/ic_chevron_left"
    case chevronRight = "Icons/ic_chevron_right"
    case xMark = "Icons/ic_x"
    case menu = "Icons/ic_menu"

    // MARK: - Actions

    case plus = "Icons/ic_plus"
    case check = "Icons/ic_check"
    case trash = "Icons/ic_trash"
    case pencil = "Icons/ic_pencil"
    case share = "Icons/ic_share"
    case download = "Icons/ic_download"
    case heart = "Icons/ic_heart"
    case star = "Icons/ic_star"
    case bookmark = "Icons/ic_bookmark"
    case wrench = "Icons/ic_wrench"

    // MARK: - Communication

    case mail = "Icons/ic_mail"
    case messageCircle = "Icons/ic_message_circle"
    case phone = "Icons/ic_phone"
    case send = "Icons/ic_send"
    case link = "Icons/ic_link"
    case atSign = "Icons/ic_at_sign"
    case sparkles = "Icons/ic_sparkles"

    // MARK: - Status

    case info = "Icons/ic_info"
    case alertCircle = "Icons/ic_alert_circle"
    case alertTriangle = "Icons/ic_alert_triangle"
    case checkCircle = "Icons/ic_check_circle"
    case xCircle = "Icons/ic_x_circle"
    case loader = "Icons/ic_loader"

    // MARK: - Media

    case play = "Icons/ic_play"
    case pause = "Icons/ic_pause"
    case skipForward = "Icons/ic_skip_forward"
    case volume = "Icons/ic_volume"
    case camera = "Icons/ic_camera"
    case image = "Icons/ic_image"
    case video = "Icons/ic_video"
    case mic = "Icons/ic_mic"

    // MARK: - People

    case user = "Icons/ic_user"
    case users = "Icons/ic_users"
    case userPlus = "Icons/ic_user_plus"
    case smile = "Icons/ic_smile"
    case userCircle = "Icons/ic_user_circle"

    // MARK: - Form

    case eye = "Icons/ic_eye"
    case eyeOff = "Icons/ic_eye_off"
    case calendar = "Icons/ic_calendar"
    case clock = "Icons/ic_clock"
    case mapPin = "Icons/ic_map_pin"
    case lock = "Icons/ic_lock"
    case filter = "Icons/ic_filter"
    case hash = "Icons/ic_hash"

    // MARK: - Commerce

    case shoppingCart = "Icons/ic_shopping_cart"
    case shoppingBag = "Icons/ic_shopping_bag"
    case creditCard = "Icons/ic_credit_card"
    case tag = "Icons/ic_tag"
    case gift = "Icons/ic_gift"
    case wallet = "Icons/ic_wallet"
    case receipt = "Icons/ic_receipt"
    case percent = "Icons/ic_percent"

    // MARK: - Files

    case file = "Icons/ic_file"
    case fileText = "Icons/ic_file_text"
    case folder = "Icons/ic_folder"
    case folderOpen = "Icons/ic_folder_open"
    case paperclip = "Icons/ic_paperclip"
    case uploadCloud = "Icons/ic_upload_cloud"
    case save = "Icons/ic_save"
    case clipboard = "Icons/ic_clipboard"

    // MARK: - Editor

    case copy = "Icons/ic_copy"
    case list = "Icons/ic_list"
    case layoutGrid = "Icons/ic_layout_grid"
    case moreHorizontal = "Icons/ic_more_horizontal"
    case moreVertical = "Icons/ic_more_vertical"
    case maximize = "Icons/ic_maximize"
    case scissors = "Icons/ic_scissors"
    case undo = "Icons/ic_undo"

    // MARK: - Arrows

    case arrowRight = "Icons/ic_arrow_right"
    case arrowUp = "Icons/ic_arrow_up"
    case arrowDown = "Icons/ic_arrow_down"
    case chevronUp = "Icons/ic_chevron_up"
    case chevronDown = "Icons/ic_chevron_down"
    case refresh = "Icons/ic_refresh"
    case logOut = "Icons/ic_log_out"
    case externalLink = "Icons/ic_external_link"

    // MARK: - Notify & Theme

    case bell = "Icons/ic_bell"
    case bellOff = "Icons/ic_bell_off"
    case wifi = "Icons/ic_wifi"
    case bluetooth = "Icons/ic_bluetooth"
    case toggle = "Icons/ic_toggle"
    case volumeX = "Icons/ic_volume_x"
    case sun = "Icons/ic_sun"
    case moon = "Icons/ic_moon"
    case app = "Icons/ic_app"

    // MARK: - UIImage

    public var uiImage: UIImage {
        UIImage(named: rawValue, in: .module, compatibleWith: nil)?
            .withRenderingMode(.alwaysTemplate) ?? UIImage()
    }
}
