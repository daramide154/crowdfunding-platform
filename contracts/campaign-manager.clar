;; Campaign Manager Contract
;; Creates and manages crowdfunding campaigns with funding goals and deadlines, handles contributor 
;; investments and tracks funding progress, manages milestone-based fund releases, and processes 
;; automatic refunds for unsuccessful campaigns.

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_NOT_FOUND (err u101))
(define-constant ERR_ALREADY_EXISTS (err u102))
(define-constant ERR_INVALID_AMOUNT (err u103))
(define-constant ERR_CAMPAIGN_ENDED (err u104))
(define-constant ERR_FUNDING_GOAL_NOT_MET (err u105))
(define-constant ERR_MILESTONE_NOT_READY (err u106))
(define-constant ERR_ALREADY_REFUNDED (err u107))
(define-constant ERR_NO_CONTRIBUTIONS (err u108))
(define-constant ERR_INVALID_MILESTONE (err u109))

;; Campaign Status Constants
(define-constant STATUS_ACTIVE u0)
(define-constant STATUS_SUCCESSFUL u1)
(define-constant STATUS_FAILED u2)
(define-constant STATUS_CANCELLED u3)

;; Data Variables
(define-data-var campaign-counter uint u0)
(define-data-var platform-fee-percentage uint u250) ;; 2.5%
(define-data-var min-campaign-duration uint u1440) ;; ~10 days in blocks
(define-data-var max-milestones uint u10)

;; Data Maps

;; Campaign registry
(define-map campaigns
  uint
  {
    title: (string-utf8 256),
    description: (string-utf8 1024),
    creator: principal,
    funding-goal: uint,
    current-funding: uint,
    deadline: uint,
    status: uint,
    milestone-count: uint,
    funds-released: uint,
    contributor-count: uint,
    created-at: uint
  }
)

;; Campaign milestones
(define-map campaign-milestones
  { campaign-id: uint, milestone-id: uint }
  {
    title: (string-utf8 256),
    description: (string-utf8 512),
    funding-percentage: uint,
    release-amount: uint,
    is-completed: bool,
    completion-votes: uint,
    total-votes: uint,
    released: bool
  }
)

;; Contributor information
(define-map contributors
  { campaign-id: uint, contributor: principal }
  {
    amount-contributed: uint,
    contribution-timestamp: uint,
    refund-claimed: bool,
    milestones-voted: (list 10 uint)
  }
)

;; Campaign creator reputation
(define-map creator-stats
  principal
  {
    total-campaigns: uint,
    successful-campaigns: uint,
    total-raised: uint,
    reputation-score: uint,
    last-campaign: uint
  }
)

;; Platform statistics
(define-map platform-stats
  (string-ascii 16)
  {
    total-campaigns: uint,
    successful-campaigns: uint,
    total-funding: uint,
    total-contributors: uint,
    platform-fees: uint
  }
)

;; Private Functions

(define-private (increment-campaign-counter)
  (let ((current-counter (var-get campaign-counter)))
    (var-set campaign-counter (+ current-counter u1))
    (+ current-counter u1)))

(define-private (is-campaign-creator (campaign-id uint) (address principal))
  (match (map-get? campaigns campaign-id)
    campaign-info (is-eq (get creator campaign-info) address)
    false))

(define-private (calculate-platform-fee (amount uint))
  (/ (* amount (var-get platform-fee-percentage)) u10000))

(define-private (update-creator-stats (creator principal) (amount uint) (successful bool))
  (let ((current-stats (default-to 
    { total-campaigns: u0, successful-campaigns: u0, total-raised: u0, reputation-score: u100, last-campaign: u0 }
    (map-get? creator-stats creator))))
    (map-set creator-stats creator {
      total-campaigns: (+ (get total-campaigns current-stats) u1),
      successful-campaigns: (+ (get successful-campaigns current-stats) (if successful u1 u0)),
      total-raised: (+ (get total-raised current-stats) amount),
      reputation-score: (if (> (+ (get total-campaigns current-stats) u1) u0)
        (* (/ (+ (get successful-campaigns current-stats) (if successful u1 u0)) 
              (+ (get total-campaigns current-stats) u1)) u100)
        u100),
      last-campaign: (var-get campaign-counter)
    })))

;; Public Functions

;; Create a new crowdfunding campaign
(define-public (create-campaign 
  (title (string-utf8 256))
  (description (string-utf8 1024))
  (funding-goal uint)
  (duration-blocks uint)
  (milestone-titles (list 5 (string-utf8 256)))
  (milestone-percentages (list 5 uint)))
  (let ((campaign-id (increment-campaign-counter))
        (deadline (+ block-height duration-blocks)))
    ;; Validate inputs
    (asserts! (> funding-goal u0) ERR_INVALID_AMOUNT)
    (asserts! (>= duration-blocks (var-get min-campaign-duration)) ERR_INVALID_AMOUNT)
    (asserts! (<= (len milestone-titles) (var-get max-milestones)) ERR_INVALID_MILESTONE)
    (asserts! (is-eq (len milestone-titles) (len milestone-percentages)) ERR_INVALID_MILESTONE)
    
    ;; Create campaign
    (map-set campaigns campaign-id {
      title: title,
      description: description,
      creator: tx-sender,
      funding-goal: funding-goal,
      current-funding: u0,
      deadline: deadline,
      status: STATUS_ACTIVE,
      milestone-count: (len milestone-titles),
      funds-released: u0,
      contributor-count: u0,
      created-at: block-height
    })
    
    ;; Create milestones
    (map create-milestone-entry 
         (map + (list u0 u1 u2 u3 u4) (list u0 u0 u0 u0 u0))
         milestone-titles 
         milestone-percentages
         (list campaign-id campaign-id campaign-id campaign-id campaign-id))
    
    (ok campaign-id)))

;; Helper function to create milestone entries
(define-private (create-milestone-entry (milestone-id uint) (title (string-utf8 256)) (percentage uint) (campaign-id uint))
  (if (< milestone-id (var-get max-milestones))
    (map-set campaign-milestones
      { campaign-id: campaign-id, milestone-id: milestone-id }
      {
        title: title,
        description: u"",
        funding-percentage: percentage,
        release-amount: u0,
        is-completed: false,
        completion-votes: u0,
        total-votes: u0,
        released: false
      })
    true))

;; Contribute to a campaign
(define-public (contribute-to-campaign (campaign-id uint) (amount uint))
  (let ((campaign-info (unwrap! (map-get? campaigns campaign-id) ERR_NOT_FOUND))
        (existing-contribution (map-get? contributors { campaign-id: campaign-id, contributor: tx-sender })))
    ;; Validate contribution
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (asserts! (is-eq (get status campaign-info) STATUS_ACTIVE) ERR_CAMPAIGN_ENDED)
    (asserts! (< block-height (get deadline campaign-info)) ERR_CAMPAIGN_ENDED)
    
    ;; Transfer STX to contract
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    
    ;; Update or create contributor record
    (match existing-contribution
      existing-info
        (map-set contributors { campaign-id: campaign-id, contributor: tx-sender }
          (merge existing-info {
            amount-contributed: (+ (get amount-contributed existing-info) amount)
          }))
      ;; New contributor
      (begin
        (map-set contributors { campaign-id: campaign-id, contributor: tx-sender } {
          amount-contributed: amount,
          contribution-timestamp: block-height,
          refund-claimed: false,
          milestones-voted: (list)
        })
        ;; Increment contributor count
        (map-set campaigns campaign-id
          (merge campaign-info {
            contributor-count: (+ (get contributor-count campaign-info) u1)
          }))))
    
    ;; Update campaign funding
    (map-set campaigns campaign-id
      (merge campaign-info {
        current-funding: (+ (get current-funding campaign-info) amount)
      }))
    
    (ok true)))

;; Release milestone funds (creator only)
(define-public (release-milestone-funds (campaign-id uint) (milestone-id uint))
  (let ((campaign-info (unwrap! (map-get? campaigns campaign-id) ERR_NOT_FOUND))
        (milestone-info (unwrap! (map-get? campaign-milestones { campaign-id: campaign-id, milestone-id: milestone-id }) ERR_NOT_FOUND)))
    ;; Only creator can release funds
    (asserts! (is-eq tx-sender (get creator campaign-info)) ERR_UNAUTHORIZED)
    
    ;; Check if milestone is completed and approved
    (asserts! (get is-completed milestone-info) ERR_MILESTONE_NOT_READY)
    (asserts! (not (get released milestone-info)) ERR_ALREADY_REFUNDED)
    
    ;; Calculate release amount
    (let ((release-amount (/ (* (get current-funding campaign-info) (get funding-percentage milestone-info)) u100))
          (platform-fee (calculate-platform-fee release-amount))
          (creator-amount (- release-amount platform-fee)))
      
      ;; Transfer funds to creator
      (try! (as-contract (stx-transfer? creator-amount tx-sender (get creator campaign-info))))
      
      ;; Update milestone status
      (map-set campaign-milestones { campaign-id: campaign-id, milestone-id: milestone-id }
        (merge milestone-info {
          released: true,
          release-amount: creator-amount
        }))
      
      ;; Update campaign funds released
      (map-set campaigns campaign-id
        (merge campaign-info {
          funds-released: (+ (get funds-released campaign-info) creator-amount)
        }))
      
      (ok creator-amount))))

;; Request refund for failed campaign
(define-public (request-refund (campaign-id uint))
  (let ((campaign-info (unwrap! (map-get? campaigns campaign-id) ERR_NOT_FOUND))
        (contributor-info (unwrap! (map-get? contributors { campaign-id: campaign-id, contributor: tx-sender }) ERR_NO_CONTRIBUTIONS)))
    
    ;; Check if campaign failed or deadline passed without meeting goal
    (asserts! 
      (or 
        (is-eq (get status campaign-info) STATUS_FAILED)
        (and 
          (>= block-height (get deadline campaign-info))
          (< (get current-funding campaign-info) (get funding-goal campaign-info))))
      ERR_FUNDING_GOAL_NOT_MET)
    
    ;; Check if refund not already claimed
    (asserts! (not (get refund-claimed contributor-info)) ERR_ALREADY_REFUNDED)
    
    ;; Calculate refund amount
    (let ((refund-amount (get amount-contributed contributor-info)))
      ;; Transfer refund
      (try! (as-contract (stx-transfer? refund-amount tx-sender tx-sender)))
      
      ;; Mark refund as claimed
      (map-set contributors { campaign-id: campaign-id, contributor: tx-sender }
        (merge contributor-info { refund-claimed: true }))
      
      (ok refund-amount))))

;; Update campaign status
(define-public (update-campaign-status (campaign-id uint) (new-status uint))
  (let ((campaign-info (unwrap! (map-get? campaigns campaign-id) ERR_NOT_FOUND)))
    ;; Only creator or contract owner can update status
    (asserts! 
      (or 
        (is-eq tx-sender (get creator campaign-info))
        (is-eq tx-sender CONTRACT_OWNER))
      ERR_UNAUTHORIZED)
    
    ;; Update campaign status
    (map-set campaigns campaign-id
      (merge campaign-info { status: new-status }))
    
    ;; Update creator stats if campaign completed
    (if (or (is-eq new-status STATUS_SUCCESSFUL) (is-eq new-status STATUS_FAILED))
      (update-creator-stats 
        (get creator campaign-info) 
        (get current-funding campaign-info)
        (is-eq new-status STATUS_SUCCESSFUL))
      true)
    
    (ok true)))

;; Read-Only Functions

;; Get campaign information
(define-read-only (get-campaign-info (campaign-id uint))
  (map-get? campaigns campaign-id))

;; Get milestone information
(define-read-only (get-milestone-info (campaign-id uint) (milestone-id uint))
  (map-get? campaign-milestones { campaign-id: campaign-id, milestone-id: milestone-id }))

;; Get contributor information
(define-read-only (get-contribution-info (campaign-id uint) (contributor principal))
  (map-get? contributors { campaign-id: campaign-id, contributor: contributor }))

;; Get campaign progress percentage
(define-read-only (get-campaign-progress (campaign-id uint))
  (match (map-get? campaigns campaign-id)
    campaign-info
      (if (> (get funding-goal campaign-info) u0)
        (* (/ (get current-funding campaign-info) (get funding-goal campaign-info)) u100)
        u0)
    u0))

;; Calculate refund amount for a contributor
(define-read-only (calculate-refund-amount (campaign-id uint) (contributor principal))
  (match (map-get? contributors { campaign-id: campaign-id, contributor: contributor })
    contributor-info
      (if (not (get refund-claimed contributor-info))
        (some (get amount-contributed contributor-info))
        none)
    none))

;; Get creator statistics
(define-read-only (get-creator-stats (creator principal))
  (map-get? creator-stats creator))

;; Get total campaigns count
(define-read-only (get-total-campaigns)
  (var-get campaign-counter))

;; Check if campaign is active
(define-read-only (is-campaign-active (campaign-id uint))
  (match (map-get? campaigns campaign-id)
    campaign-info
      (and 
        (is-eq (get status campaign-info) STATUS_ACTIVE)
        (< block-height (get deadline campaign-info)))
    false))


;; title: campaign-manager
;; version:
;; summary:
;; description:

;; traits
;;

;; token definitions
;;

;; constants
;;

;; data vars
;;

;; data maps
;;

;; public functions
;;

;; read only functions
;;

;; private functions
;;

