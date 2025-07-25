//
//  MyPageCommentViewController.swift
//  DontBe-iOS
//
//  Created by 변상우 on 1/11/24.
//

import Combine
import UIKit

import SnapKit

final class MyPageCommentViewController: UIViewController {
    
    // MARK: - Properties
    
    static let pushViewController = NSNotification.Name("pushViewController")
    static let reloadData = NSNotification.Name("reloadData")
    static let warnUserButtonTapped = NSNotification.Name("warnUserButtonTapped")
    static let ghostButtonTapped = NSNotification.Name("ghostButtonCommentTapped")
    static let reloadCommentData = NSNotification.Name("reloadCommentData")
    
    var showUploadToastView: Bool = false
    var deleteBottomsheet = DontBeBottomSheetView(singleButtonImage: ImageLiterals.Posting.btnDelete)
    private let refreshControl = UIRefreshControl()
    
    private let postViewModel: PostDetailViewModel
    private let myPageViewModel: MyPageViewModel
    let deleteViewModel = DeleteReplyViewModel(networkProvider: NetworkService())
    private var cancelBag = CancelBag()
    
    var profileData: [MypageProfileResponseDTO] = []
    var commentDatas: [MyPageMemberCommentResponseDTO] = []
    
    // var commentData = MyPageViewModel(networkProvider: NetworkService()).myPageCommentData
    var contentId: Int = 0
    var commentId: Int = 0
    var alarmTriggerType: String = ""
    var targetMemberId: Int = 0
    var alarmTriggerdId: Int = 0
    
    // MARK: - UI Components
    
    lazy var homeCollectionView = HomeCollectionView().collectionView
    let noCommentLabel: UILabel = {
        let label = UILabel()
        label.text = StringLiterals.MyPage.myPageNoCommentLabel
        label.textColor = .donGray7
        label.font = .font(.body2)
        label.numberOfLines = 0
        label.textAlignment = .center
        return label
    }()
    
    var deleteReplyPopupVC = DeleteReplyPopupViewController(viewModel: DeleteReplyViewModel(networkProvider: NetworkService()))
    var warnBottomsheet = DontBeBottomSheetView(singleButtonImage: ImageLiterals.Posting.btnWarn)
    
    // MARK: - Life Cycles
    
    init(viewModel: PostDetailViewModel, myPageViewModel: MyPageViewModel) {
        self.postViewModel = viewModel
        self.myPageViewModel = myPageViewModel
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setUI()
        setHierarchy()
        setLayout()
        setDelegate()
        setRefreshControll()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(true)
        
        refreshPostDidDrag()
        setNotification()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        NotificationCenter.default.removeObserver(self, name: MyPageCommentViewController.reloadData, object: nil)
    }
}

// MARK: - Extensions

extension MyPageCommentViewController {
    private func setUI() {
        self.view.backgroundColor = UIColor.donGray1
        self.navigationController?.navigationBar.isHidden = true
        
        deleteReplyPopupVC.modalPresentationStyle = .overFullScreen
    }
    
    private func setHierarchy() {
        view.addSubviews(homeCollectionView, noCommentLabel)
    }
    
    private func setLayout() {
        homeCollectionView.snp.makeConstraints {
            $0.edges.equalToSuperview()
            $0.width.equalToSuperview()
        }
        
        noCommentLabel.snp.makeConstraints {
            $0.top.equalToSuperview().inset(44.adjusted)
            $0.leading.trailing.equalToSuperview().inset(20.adjusted)
        }
    }
    
    private func setDelegate() {
        homeCollectionView.dataSource = self
        homeCollectionView.delegate = self
    }
    
    private func setRefreshControll() {
        refreshControl.addTarget(self, action: #selector(refreshPostDidDrag), for: .valueChanged)
        homeCollectionView.refreshControl = refreshControl
        refreshControl.backgroundColor = .donGray1
    }
    
    private func setNotification() {
        NotificationCenter.default.addObserver(self, selector: #selector(reloadData), name: MyPageCommentViewController.reloadData, object: nil)
    }
    
    @objc
    func refreshPostDidDrag() {
        DispatchQueue.main.async {
            self.homeCollectionView.reloadData()
        }
        self.perform(#selector(self.finishedRefreshing), with: nil, afterDelay: 0.1)
    }
    
    @objc
    func reloadData(_ notification: Notification) {
        refreshPostDidDrag()
    }
    
    @objc
    func finishedRefreshing() {
        refreshControl.endRefreshing()
    }
    
    @objc
    private func deleteButtonTapped() {
        popDeleteView()
        deleteReplyPopupView()
    }
    
    @objc
    private func warnButtonTapped() {
        popWarnView()
        NotificationCenter.default.post(name: MyPageContentViewController.warnUserButtonTapped, object: nil)
    }
    
    func popDeleteView() {
        if UIApplication.shared.keyWindowInConnectedScenes != nil {
            UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 1, initialSpringVelocity: 1, options: .curveEaseOut, animations: {
                self.deleteBottomsheet.dimView.alpha = 0
                if let window = UIApplication.shared.keyWindowInConnectedScenes {
                    self.deleteBottomsheet.bottomsheetView.frame = CGRect(x: 0, y: window.frame.height, width: self.deleteBottomsheet.frame.width, height: self.deleteBottomsheet.bottomsheetView.frame.height)
                }
            })
            deleteBottomsheet.dimView.removeFromSuperview()
            deleteBottomsheet.bottomsheetView.removeFromSuperview()
        }
        refreshPostDidDrag()
    }
    
    func popWarnView() {
        if UIApplication.shared.keyWindowInConnectedScenes != nil {
            UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 1, initialSpringVelocity: 1, options: .curveEaseOut, animations: {
                self.warnBottomsheet.dimView.alpha = 0
                if let window = UIApplication.shared.keyWindowInConnectedScenes {
                    self.warnBottomsheet.bottomsheetView.frame = CGRect(x: 0, y: window.frame.height, width: self.deleteBottomsheet.frame.width, height: self.warnBottomsheet.bottomsheetView.frame.height)
                }
            })
            warnBottomsheet.dimView.removeFromSuperview()
            warnBottomsheet.bottomsheetView.removeFromSuperview()
        }
        refreshPostDidDrag()
    }
    
    func presentView() {
        deleteReplyPopupVC.commentId = self.commentId
        self.present(self.deleteReplyPopupVC, animated: false, completion: nil)
    }
    
    private func postCommentLikeButtonAPI(isClicked: Bool, commentId: Int, commentText: String) {
        // 최초 한 번만 publisher 생성
        let commentLikedButtonTapped: AnyPublisher<(Bool, Int, String), Never>? = Just(())
            .map { _ in return (!isClicked, commentId, commentText) }
            .throttle(for: .seconds(2), scheduler: DispatchQueue.main, latest: false)
            .eraseToAnyPublisher()
        
        let input = PostDetailViewModel.Input(viewUpdate: nil,
                                              likeButtonTapped: nil,
                                              collectionViewUpdata: nil,
                                              commentLikeButtonTapped: commentLikedButtonTapped,
                                              firstReasonButtonTapped: nil,
                                              secondReasonButtonTapped: nil,
                                              thirdReasonButtonTapped: nil,
                                              fourthReasonButtonTapped: nil,
                                              fifthReasonButtonTapped: nil,
                                              sixthReasonButtonTapped: nil)
        
        let output = self.postViewModel.transform(from: input, cancelBag: self.cancelBag)
        
        output.toggleLikeButton
            .sink { _ in }
            .store(in: self.cancelBag)
    }
    
    func deleteReplyPopupView() {
        deleteReplyPopupVC.commentId = self.commentId
        self.present(self.deleteReplyPopupVC, animated: false, completion: nil)
    }
}

extension MyPageCommentViewController: UICollectionViewDelegate { }

extension MyPageCommentViewController: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return commentDatas.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell =
        HomeCollectionViewCell.dequeueReusableCell(collectionView: collectionView, indexPath: indexPath)
        
        cell.alarmTriggerType = "commentGhost"
        cell.targetMemberId = commentDatas[indexPath.row].memberId
        cell.alarmTriggerdId = commentDatas[indexPath.row].commentId
        
        if commentDatas[indexPath.row].memberId == loadUserData()?.memberId {
            cell.ghostButton.isHidden = true
            cell.verticalTextBarView.isHidden = true
            self.deleteBottomsheet.warnButton.removeFromSuperview()
            
            cell.KebabButtonAction = {
                self.deleteBottomsheet.showSettings()
                self.deleteBottomsheet.deleteButton.addTarget(self, action: #selector(self.deleteButtonTapped), for: .touchUpInside)
                self.commentId = self.commentDatas[indexPath.row].commentId
            }
        } else {
            cell.ghostButton.isHidden = false
            cell.verticalTextBarView.isHidden = false
            self.warnBottomsheet.deleteButton.removeFromSuperview()
            
            cell.KebabButtonAction = {
                self.warnBottomsheet.showSettings()
                self.warnBottomsheet.warnButton.addTarget(self, action: #selector(self.warnButtonTapped), for: .touchUpInside)
                self.commentId = self.commentDatas[indexPath.row].commentId
            }
        }
        
        cell.LikeButtonAction = {
            if cell.isLiked == true {
                cell.likeNumLabel.text = String((Int(cell.likeNumLabel.text ?? "") ?? 0) - 1)
            } else {
                cell.likeNumLabel.text = String((Int(cell.likeNumLabel.text ?? "") ?? 0) + 1)
            }
            cell.isLiked.toggle()
            cell.likeButton.setImage(cell.isLiked ? ImageLiterals.Posting.btnFavoriteActive : ImageLiterals.Posting.btnFavoriteInActive, for: .normal)
            self.postCommentLikeButtonAPI(isClicked: cell.isLiked, commentId: self.commentDatas[indexPath.row].commentId, commentText: self.commentDatas[indexPath.row].commentText)
        }
        
        cell.ProfileButtonAction = {
            let memberId = self.commentDatas[indexPath.row].memberId

            if memberId == loadUserData()?.memberId ?? 0  {
                self.tabBarController?.selectedIndex = 3
                if let selectedViewController = self.tabBarController?.selectedViewController {
                    self.applyTabBarAttributes(to: selectedViewController.tabBarItem, isSelected: true)
                }
                let myViewController = self.tabBarController?.viewControllers ?? [UIViewController()]
                for (index, controller) in myViewController.enumerated() {
                    if let tabBarItem = controller.tabBarItem {
                        if index != self.tabBarController?.selectedIndex {
                            self.applyTabBarAttributes(to: tabBarItem, isSelected: false)
                        }
                    }
                }
            } else {
                let viewController = MyPageViewController(viewModel: MyPageViewModel(networkProvider: NetworkService()))
                viewController.memberId = memberId
                self.navigationController?.pushViewController(viewController, animated: true)
            }
        }
        
        cell.TransparentButtonAction = {
            self.alarmTriggerType = cell.alarmTriggerType
            self.targetMemberId = cell.targetMemberId
            self.alarmTriggerdId = cell.alarmTriggerdId
            NotificationCenter.default.post(name: MyPageCommentViewController.ghostButtonTapped, object: nil)
        }
        
        cell.nicknameLabel.text = commentDatas[indexPath.row].memberNickname
        cell.transparentLabel.text = "투명도 \(commentDatas[indexPath.row].memberGhost)%"
        cell.timeLabel.text = "\(commentDatas[indexPath.row].time.formattedTime())"
        cell.contentTextLabel.text = commentDatas[indexPath.row].commentText
        cell.likeNumLabel.text = "\(commentDatas[indexPath.row].commentLikedNumber)"
        cell.commentNumLabel.text = "\(commentDatas[indexPath.row].commentLikedNumber)"
        cell.profileImageView.load(url: "\(commentDatas[indexPath.row].memberProfileUrl)")
        
        cell.configure(with: cell.contentTextLabel.text ?? "")
        
        cell.likeButton.setImage(commentDatas[indexPath.row].isLiked ? ImageLiterals.Posting.btnFavoriteActive : ImageLiterals.Posting.btnFavoriteInActive, for: .normal)
        cell.isLiked = commentDatas[indexPath.row].isLiked
        
        cell.likeStackView.snp.remakeConstraints {
            $0.top.equalTo(cell.contentTextLabel.snp.bottom).offset(4.adjusted)
            $0.height.equalTo(cell.commentStackView)
            $0.trailing.equalTo(cell.kebabButton).inset(8.adjusted)
        }
        
        cell.commentStackView.isHidden = true
        
        // 내가 투명도를 누른 유저인 경우 -85% 적용
        if commentDatas[indexPath.row].isGhost {
            cell.grayView.alpha = 0.85
        } else {
            let alpha = commentDatas[indexPath.row].memberGhost
            cell.grayView.alpha = CGFloat(Double(-alpha) / 100)
        }
        
        self.commentId = commentDatas[indexPath.row].commentId
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let contentId = commentDatas[indexPath.row].contentId
        let profileImageURL = commentDatas[indexPath.row].memberProfileUrl
        NotificationCenter.default.post(name: MyPageContentViewController.pushViewController, object: nil, userInfo: ["contentId": contentId, "profileImageURL": profileImageURL])
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if scrollView == homeCollectionView {
            if (scrollView.contentOffset.y + scrollView.frame.size.height) >= (scrollView.contentSize.height) {
                let lastCommentId = commentDatas.last?.commentId ?? -1
                myPageViewModel.commentCursor = lastCommentId
                NotificationCenter.default.post(name: MyPageCommentViewController.reloadCommentData, object: nil, userInfo: ["commentCursor": lastCommentId])
                DispatchQueue.main.async {
                     self.homeCollectionView.reloadData()
                }
            }
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        guard let footer = homeCollectionView.dequeueReusableSupplementaryView(ofKind: UICollectionView.elementKindSectionFooter, withReuseIdentifier: "HomeCollectionFooterView", for: indexPath) as? HomeCollectionFooterView else { return UICollectionReusableView() }
        return footer
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: 343.adjusted, height: 210.adjusted)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForFooterInSection section: Int) -> CGSize {
        
        return CGSize(width: UIScreen.main.bounds.width, height: 24.adjusted)
    }
}

extension MyPageCommentViewController: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let yOffset = scrollView.contentOffset.y
        if yOffset > 0 {
            scrollView.isScrollEnabled = true
        } else if yOffset < 0 {
            scrollView.isScrollEnabled = false
        }
    }
}

extension MyPageCommentViewController: DontBePopupDelegate {
    func cancleButtonTapped() {
//        transparentButtonPopupView.alpha = 0
    }
    
    func confirmButtonTapped() {
//        transparentButtonPopupView.alpha = 0
        // ✅ 투명도 주기 버튼 클릭 시 액션 추가
    }
}
