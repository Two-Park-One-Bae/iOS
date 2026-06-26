import UIKit

public enum DSIcon: String {

    // MARK: - Navigation

    case house = "Icons/Navigation/ic_house"
    case search = "Icons/Navigation/ic_search"
    case compass = "Icons/Navigation/ic_compass"
    case settings = "Icons/Navigation/ic_settings"
    case arrowLeft = "Icons/Navigation/ic_arrow_left"
    case chevronLeft = "Icons/Navigation/ic_chevron_left"
    case chevronRight = "Icons/Navigation/ic_chevron_right"
    case xMark = "Icons/Navigation/ic_x"
    case menu = "Icons/Navigation/ic_menu"

    // MARK: - Actions

    case plus = "Icons/Actions/ic_plus"
    case check = "Icons/Actions/ic_check"
    case trash = "Icons/Actions/ic_trash"
    case pencil = "Icons/Actions/ic_pencil"
    case share = "Icons/Actions/ic_share"
    case download = "Icons/Actions/ic_download"
    case heart = "Icons/Actions/ic_heart"
    case star = "Icons/Actions/ic_star"
    case bookmark = "Icons/Actions/ic_bookmark"
    case wrench = "Icons/Actions/ic_wrench"

    // MARK: - Communication

    case mail = "Icons/Communication/ic_mail"
    case messageCircle = "Icons/Communication/ic_message_circle"
    case phone = "Icons/Communication/ic_phone"
    case send = "Icons/Communication/ic_send"
    case link = "Icons/Communication/ic_link"
    case atSign = "Icons/Communication/ic_at_sign"
    case sparkles = "Icons/Communication/ic_sparkles"

    // MARK: - Status

    case info = "Icons/Status/ic_info"
    case alertCircle = "Icons/Status/ic_alert_circle"
    case alertTriangle = "Icons/Status/ic_alert_triangle"
    case checkCircle = "Icons/Status/ic_check_circle"
    case xCircle = "Icons/Status/ic_x_circle"
    case loader = "Icons/Status/ic_loader"

    // MARK: - Media

    case play = "Icons/Media/ic_play"
    case pause = "Icons/Media/ic_pause"
    case skipForward = "Icons/Media/ic_skip_forward"
    case volume = "Icons/Media/ic_volume"
    case camera = "Icons/Media/ic_camera"
    case image = "Icons/Media/ic_image"
    case video = "Icons/Media/ic_video"
    case mic = "Icons/Media/ic_mic"

    // MARK: - People

    case user = "Icons/People/ic_user"
    case users = "Icons/People/ic_users"
    case userPlus = "Icons/People/ic_user_plus"
    case smile = "Icons/People/ic_smile"
    case userCircle = "Icons/People/ic_user_circle"

    // MARK: - Form

    case eye = "Icons/Form/ic_eye"
    case eyeOff = "Icons/Form/ic_eye_off"
    case calendar = "Icons/Form/ic_calendar"
    case clock = "Icons/Form/ic_clock"
    case mapPin = "Icons/Form/ic_map_pin"
    case lock = "Icons/Form/ic_lock"
    case filter = "Icons/Form/ic_filter"
    case hash = "Icons/Form/ic_hash"

    // MARK: - Commerce

    case shoppingCart = "Icons/Commerce/ic_shopping_cart"
    case shoppingBag = "Icons/Commerce/ic_shopping_bag"
    case creditCard = "Icons/Commerce/ic_credit_card"
    case tag = "Icons/Commerce/ic_tag"
    case gift = "Icons/Commerce/ic_gift"
    case wallet = "Icons/Commerce/ic_wallet"
    case receipt = "Icons/Commerce/ic_receipt"
    case percent = "Icons/Commerce/ic_percent"

    // MARK: - Files

    case file = "Icons/Files/ic_file"
    case fileText = "Icons/Files/ic_file_text"
    case folder = "Icons/Files/ic_folder"
    case folderOpen = "Icons/Files/ic_folder_open"
    case paperclip = "Icons/Files/ic_paperclip"
    case uploadCloud = "Icons/Files/ic_upload_cloud"
    case save = "Icons/Files/ic_save"
    case clipboard = "Icons/Files/ic_clipboard"

    // MARK: - Editor

    case copy = "Icons/Editor/ic_copy"
    case list = "Icons/Editor/ic_list"
    case layoutGrid = "Icons/Editor/ic_layout_grid"
    case moreHorizontal = "Icons/Editor/ic_more_horizontal"
    case moreVertical = "Icons/Editor/ic_more_vertical"
    case maximize = "Icons/Editor/ic_maximize"
    case scissors = "Icons/Editor/ic_scissors"
    case undo = "Icons/Editor/ic_undo"

    // MARK: - Arrows

    case arrowRight = "Icons/Arrows/ic_arrow_right"
    case arrowUp = "Icons/Arrows/ic_arrow_up"
    case arrowDown = "Icons/Arrows/ic_arrow_down"
    case chevronUp = "Icons/Arrows/ic_chevron_up"
    case chevronDown = "Icons/Arrows/ic_chevron_down"
    case refresh = "Icons/Arrows/ic_refresh"
    case logOut = "Icons/Arrows/ic_log_out"
    case externalLink = "Icons/Arrows/ic_external_link"

    // MARK: - Notify & Theme

    case bell = "Icons/Notify/ic_bell"
    case bellOff = "Icons/Notify/ic_bell_off"
    case wifi = "Icons/Notify/ic_wifi"
    case bluetooth = "Icons/Notify/ic_bluetooth"
    case toggle = "Icons/Notify/ic_toggle"
    case volumeX = "Icons/Notify/ic_volume_x"
    case sun = "Icons/Notify/ic_sun"
    case moon = "Icons/Notify/ic_moon"
    case app = "Icons/Notify/ic_app"

    // MARK: - UIImage

    public var uiImage: UIImage {
        UIImage(named: rawValue, in: .module, compatibleWith: nil)?
            .withRenderingMode(.alwaysTemplate) ?? UIImage()
    }
}
