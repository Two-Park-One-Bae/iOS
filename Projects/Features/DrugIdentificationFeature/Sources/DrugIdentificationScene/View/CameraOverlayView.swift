import UIKit
import DSKit

final class CameraOverlayView: UIView {

    // MARK: - Callbacks

    var onClose: (() -> Void)?
    var onShutter: (() -> Void)?
    var onGallery: (() -> Void)?
    var onFlash: (() -> Void)?

    // MARK: - Private

    private let flashButton = UIButton(type: .system)

    // MARK: - Init

    init() {
        super.init(frame: UIScreen.main.bounds)
        isUserInteractionEnabled = true
        backgroundColor = .clear
        setupOverlay()
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Public

    func updateFlashIcon(isOn: Bool) {
        let name = isOn ? "bolt.fill" : "bolt.slash.fill"
        let cfg = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        flashButton.setImage(UIImage(systemName: name, withConfiguration: cfg), for: .normal)
    }

    // MARK: - Layout

    private func setupOverlay() {
        let w = bounds.width
        let h = bounds.height

        let window = UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first
        let safeTop = window?.safeAreaInsets.top ?? 59
        let safeBottom = window?.safeAreaInsets.bottom ?? 34

        let topBarH: CGFloat = 56
        let controlsH: CGFloat = 140
        let squareSize: CGFloat = w

        let topBarY = safeTop
        let viewfinderTop = topBarY + topBarH
        let controlsTop = h - controlsH - safeBottom
        let viewfinderH = controlsTop - viewfinderTop
        let dimTopH = max(0, (viewfinderH - squareSize) / 2)
        let squareY = viewfinderTop + dimTopH
        let squareBottom = squareY + squareSize

        // ─── Dim: Top (status bar + top bar → square) ───
        let topDim = UIView(frame: CGRect(x: 0, y: 0, width: w, height: squareY))
        topDim.backgroundColor = DSColor.Neutral._900
        addSubview(topDim)

        // ─── Top Bar: Close (DSIcon.xMark, 26×26) ───
        let closeBtn = UIButton(type: .system)
        closeBtn.setImage(DSIcon.xMark.uiImage, for: .normal)
        closeBtn.tintColor = DSColor.Neutral._0
        closeBtn.frame = CGRect(x: 16, y: topBarY + (topBarH - 26) / 2, width: 26, height: 26)
        closeBtn.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        addSubview(closeBtn)

        // ─── Top Bar: Title ───
        let titleLabel = UILabel(frame: CGRect(x: 0, y: topBarY, width: w, height: topBarH))
        titleLabel.text = "알약 촬영"
        titleLabel.textAlignment = .center
        titleLabel.textColor = DSColor.Neutral._0
        titleLabel.font = DSKitFontFamily.Pretendard.semiBold.font(size: 17)
        addSubview(titleLabel)

        // ─── Top Bar: Flash (24×24, SF Symbol — DSIcon에 없음) ───
        let flashCfg = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        flashButton.setImage(UIImage(systemName: "bolt.fill", withConfiguration: flashCfg), for: .normal)
        flashButton.tintColor = DSColor.Neutral._0
        flashButton.frame = CGRect(x: w - 16 - 24, y: topBarY + (topBarH - 24) / 2, width: 24, height: 24)
        flashButton.addTarget(self, action: #selector(flashTapped), for: .touchUpInside)
        addSubview(flashButton)

        // ─── Capture Square Border (#FFFFFFB3, 2px) ───
        let squareBorder = UIView(frame: CGRect(x: 0, y: squareY, width: squareSize, height: squareSize))
        squareBorder.backgroundColor = .clear
        squareBorder.layer.borderColor = UIColor.white.withAlphaComponent(0.7).cgColor
        squareBorder.layer.borderWidth = 2
        squareBorder.isUserInteractionEnabled = false
        addSubview(squareBorder)

        // ─── Dim: Below Square ───
        let dimBottomH = controlsTop - squareBottom
        if dimBottomH > 0 {
            let bottomDim = UIView(frame: CGRect(x: 0, y: squareBottom, width: w, height: dimBottomH))
            bottomDim.backgroundColor = DSColor.Neutral._900
            addSubview(bottomDim)

            // Guide Hint (pill, bg #000000A6, padding [9, 16])
            let hintText = "알약을 겹치지 않게 펼쳐놓으세요"
            let hintFont = DSKitFontFamily.Pretendard.medium.font(size: 14)
            let hintSize = (hintText as NSString).size(withAttributes: [.font: hintFont])
            let hintW = hintSize.width + 32
            let hintH = hintSize.height + 18
            let hintBg = UIView(frame: CGRect(
                x: (w - hintW) / 2,
                y: 20,
                width: hintW,
                height: hintH
            ))
            hintBg.backgroundColor = UIColor.black.withAlphaComponent(0.65)
            hintBg.layer.cornerRadius = hintH / 2
            bottomDim.addSubview(hintBg)

            let hintLabel = UILabel(frame: hintBg.bounds)
            hintLabel.text = hintText
            hintLabel.textAlignment = .center
            hintLabel.textColor = DSColor.Neutral._0
            hintLabel.font = hintFont
            hintBg.addSubview(hintLabel)
        }

        // ─── Controls Area ───
        let controlsDim = UIView(frame: CGRect(x: 0, y: controlsTop, width: w, height: h - controlsTop))
        controlsDim.backgroundColor = DSColor.Neutral._900
        addSubview(controlsDim)

        let btnCenterY = controlsH / 2

        // Gallery (DSIcon.image, 48×48, bg Neutral._700, corner 12)
        let galleryBtn = UIButton(type: .system)
        galleryBtn.frame = CGRect(x: 36, y: btnCenterY - 24, width: 48, height: 48)
        galleryBtn.backgroundColor = DSColor.Neutral._700
        galleryBtn.layer.cornerRadius = DSRadius.md
        galleryBtn.layer.borderColor = UIColor.white.withAlphaComponent(0.2).cgColor
        galleryBtn.layer.borderWidth = 1
        galleryBtn.setImage(DSIcon.image.uiImage, for: .normal)
        galleryBtn.tintColor = DSColor.Neutral._0
        galleryBtn.imageView?.contentMode = .scaleAspectFit
        let galleryInset: CGFloat = 13
        galleryBtn.imageEdgeInsets = UIEdgeInsets(
            top: galleryInset, left: galleryInset,
            bottom: galleryInset, right: galleryInset
        )
        galleryBtn.addTarget(self, action: #selector(galleryTapped), for: .touchUpInside)
        controlsDim.addSubview(galleryBtn)

        // Shutter (74×74, border white 4px / inner 58×58)
        let shutterOuter = UIView(frame: CGRect(x: (w - 74) / 2, y: btnCenterY - 37, width: 74, height: 74))
        shutterOuter.layer.cornerRadius = 37
        shutterOuter.layer.borderColor = DSColor.Neutral._0.cgColor
        shutterOuter.layer.borderWidth = 4
        shutterOuter.backgroundColor = .clear
        controlsDim.addSubview(shutterOuter)

        let shutterInner = UIButton(type: .custom)
        shutterInner.frame = CGRect(x: 8, y: 8, width: 58, height: 58)
        shutterInner.layer.cornerRadius = 29
        shutterInner.backgroundColor = DSColor.Neutral._0
        shutterInner.addTarget(self, action: #selector(shutterTapped), for: .touchUpInside)
        shutterOuter.addSubview(shutterInner)
    }

    // MARK: - Actions

    @objc private func closeTapped() { onClose?() }
    @objc private func shutterTapped() { onShutter?() }
    @objc private func galleryTapped() { onGallery?() }
    @objc private func flashTapped() { onFlash?() }
}
