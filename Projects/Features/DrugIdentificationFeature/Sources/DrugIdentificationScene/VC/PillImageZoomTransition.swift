import UIKit
import Then

// 후보 이미지 비교 진입 트랜지션 (NM-354)
//
// 구글·네이버 이미지 뷰어처럼, 탭한 썸네일 위치에서 후보 카드 이미지 자리로 확대되며 뜬다.
// sourceFrame(썸네일의 윈도우 좌표) → 후보 이미지 뷰 프레임으로 이동하는 이미지뷰 + 배경 페이드.
final class PillImageZoomTransition: NSObject, UIViewControllerTransitioningDelegate {

    private let sourceFrame: CGRect      // 탭한 썸네일의 윈도우 좌표
    private let sourceImage: UIImage?    // 썸네일 이미지(확대 대상)

    init(sourceFrame: CGRect, sourceImage: UIImage?) {
        self.sourceFrame = sourceFrame
        self.sourceImage = sourceImage
    }

    func animationController(
        forPresented presented: UIViewController,
        presenting: UIViewController,
        source: UIViewController
    ) -> UIViewControllerAnimatedTransitioning? {
        PillImageZoomAnimator(presenting: true, sourceFrame: sourceFrame, sourceImage: sourceImage)
    }

    func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        PillImageZoomAnimator(presenting: false, sourceFrame: sourceFrame, sourceImage: sourceImage)
    }
}

private final class PillImageZoomAnimator: NSObject, UIViewControllerAnimatedTransitioning {

    private let presenting: Bool
    private let sourceFrame: CGRect
    private let sourceImage: UIImage?

    init(presenting: Bool, sourceFrame: CGRect, sourceImage: UIImage?) {
        self.presenting = presenting
        self.sourceFrame = sourceFrame
        self.sourceImage = sourceImage
    }

    func transitionDuration(using ctx: UIViewControllerContextTransitioning?) -> TimeInterval { 0.32 }

    func animateTransition(using ctx: UIViewControllerContextTransitioning) {
        presenting ? animatePresent(ctx) : animateDismiss(ctx)
    }

    private func animatePresent(_ ctx: UIViewControllerContextTransitioning) {
        let container = ctx.containerView
        guard let toVC = ctx.viewController(forKey: .to) as? PillImageComparisonVC,
              let toView = ctx.view(forKey: .to) else {
            ctx.completeTransition(false); return
        }
        container.addSubview(toView)
        toView.frame = container.bounds
        toView.layoutIfNeeded()

        let target = targetFrame(in: container, for: toVC)
        let mover = UIImageView(image: sourceImage ?? toVC.candidateImageView.image).then {
            $0.contentMode = .scaleAspectFit
            $0.clipsToBounds = true
            $0.frame = container.convert(sourceFrame, from: nil)
            $0.layer.cornerRadius = 8
        }
        container.addSubview(mover)

        toView.alpha = 0
        toVC.candidateImageView.alpha = 0

        UIView.animate(withDuration: transitionDuration(using: ctx), delay: 0, options: .curveEaseInOut) {
            toView.alpha = 1
            mover.frame = target
            mover.layer.cornerRadius = 0
        } completion: { _ in
            toVC.candidateImageView.alpha = 1
            mover.removeFromSuperview()
            ctx.completeTransition(!ctx.transitionWasCancelled)
        }
    }

    private func animateDismiss(_ ctx: UIViewControllerContextTransitioning) {
        let container = ctx.containerView
        guard let fromVC = ctx.viewController(forKey: .from) as? PillImageComparisonVC,
              let fromView = ctx.view(forKey: .from) else {
            ctx.completeTransition(false); return
        }
        let start = targetFrame(in: container, for: fromVC)
        let mover = UIImageView(image: fromVC.candidateImageView.image ?? sourceImage).then {
            $0.contentMode = .scaleAspectFit
            $0.clipsToBounds = true
            $0.frame = start
        }
        container.addSubview(mover)
        fromVC.candidateImageView.alpha = 0

        UIView.animate(withDuration: transitionDuration(using: ctx), delay: 0, options: .curveEaseInOut) {
            fromView.alpha = 0
            mover.frame = container.convert(self.sourceFrame, from: nil)
            mover.layer.cornerRadius = 8
        } completion: { _ in
            mover.removeFromSuperview()
            ctx.completeTransition(!ctx.transitionWasCancelled)
        }
    }

    // 후보 이미지 뷰의 컨테이너 좌표 프레임(레이아웃 확정 후).
    private func targetFrame(in container: UIView, for vc: PillImageComparisonVC) -> CGRect {
        let iv = vc.candidateImageView
        guard let sv = iv.superview else { return container.bounds }
        return sv.convert(iv.frame, to: container)
    }
}
