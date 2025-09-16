;; Governance Controller Contract
;; Enables contributor voting on campaign milestones and fund releases, manages creator reputation 
;; scoring based on delivery history, handles dispute resolution through community voting, and 
;; enforces platform governance rules and fee structures.

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u200))
(define-constant ERR_NOT_FOUND (err u201))
(define-constant ERR_ALREADY_VOTED (err u202))
(define-constant ERR_VOTING_ENDED (err u203))
(define-constant ERR_INSUFFICIENT_STAKE (err u204))
(define-constant ERR_DISPUTE_EXISTS (err u205))
(define-constant ERR_INVALID_VOTE (err u206))
(define-constant ERR_NOT_CONTRIBUTOR (err u207))
(define-constant ERR_DISPUTE_RESOLVED (err u208))

;; Voting Constants
(define-constant VOTE_YES u1)
(define-constant VOTE_NO u0)
(define-constant VOTE_ABSTAIN u2)

;; Dispute Status Constants
(define-constant DISPUTE_OPEN u0)
(define-constant DISPUTE_VOTING u1)
(define-constant DISPUTE_RESOLVED u2)
(define-constant DISPUTE_ESCALATED u3)

;; Data Variables
(define-data-var dispute-counter uint u0)
(define-data-var proposal-counter uint u0)
(define-data-var voting-period-blocks uint u1008) ;; ~7 days
(define-data-var min-voting-threshold uint u3) ;; Minimum votes needed
(define-data-var reputation-decay-rate uint u5) ;; 5% decay per failed project

;; Data Maps

;; Milestone voting records
(define-map milestone-votes
  { campaign-id: uint, milestone-id: uint, voter: principal }
  {
    vote: uint,
    voting-power: uint,
    voted-at: uint,
    stake-amount: uint
  }
)

;; Milestone voting results
(define-map milestone-voting-results
  { campaign-id: uint, milestone-id: uint }
  {
    yes-votes: uint,
    no-votes: uint,
    abstain-votes: uint,
    total-voting-power: uint,
    voting-deadline: uint,
    is-approved: bool,
    finalized: bool
  }
)

;; Dispute records
(define-map disputes
  uint
  {
    campaign-id: uint,
    disputer: principal,
    dispute-reason: (string-utf8 512),
    evidence-hash: (buff 32),
    created-at: uint,
    status: uint,
    resolution: (string-utf8 512),
    resolver: principal,
    resolved-at: uint
  }
)

;; Dispute voting
(define-map dispute-votes
  { dispute-id: uint, voter: principal }
  {
    vote: uint,
    voted-at: uint,
    voting-power: uint
  }
)

;; Creator reputation tracking
(define-map creator-reputation
  principal
  {
    base-score: uint,
    milestone-completion-rate: uint,
    dispute-count: uint,
    successful-resolutions: uint,
    last-updated: uint,
    reputation-multiplier: uint
  }
)

;; Platform governance proposals
(define-map governance-proposals
  uint
  {
    proposal-type: (string-ascii 32),
    title: (string-utf8 256),
    description: (string-utf8 1024),
    proposer: principal,
    created-at: uint,
    voting-deadline: uint,
    yes-votes: uint,
    no-votes: uint,
    status: uint,
    execution-data: (buff 128)
  }
)

;; Governance voting records
(define-map governance-votes
  { proposal-id: uint, voter: principal }
  {
    vote: uint,
    voting-power: uint,
    voted-at: uint
  }
)

;; Contributor voting power based on contributions
(define-map contributor-power
  principal
  {
    total-contributions: uint,
    voting-power: uint,
    reputation-bonus: uint,
    last-updated: uint
  }
)

;; Private Functions

(define-private (increment-dispute-counter)
  (let ((current-counter (var-get dispute-counter)))
    (var-set dispute-counter (+ current-counter u1))
    (+ current-counter u1)))

(define-private (increment-proposal-counter)
  (let ((current-counter (var-get proposal-counter)))
    (var-set proposal-counter (+ current-counter u1))
    (+ current-counter u1)))

(define-private (calculate-voting-power (contribution-amount uint) (reputation-score uint))
  (let ((base-power (/ contribution-amount u1000000)) ;; 1 power per 1 STX
        (reputation-bonus (/ (* base-power reputation-score) u100)))
    (+ base-power reputation-bonus)))

(define-private (update-reputation-score (creator principal) (milestone-completed bool) (disputed bool))
  (let ((current-rep (default-to 
    { base-score: u100, milestone-completion-rate: u100, dispute-count: u0, 
      successful-resolutions: u0, last-updated: u0, reputation-multiplier: u100 }
    (map-get? creator-reputation creator))))
    
    (let ((new-dispute-count (if disputed (+ (get dispute-count current-rep) u1) (get dispute-count current-rep)))
          (new-completion-rate (if milestone-completed 
            (if (> (+ (get milestone-completion-rate current-rep) u5) u100) u100 (+ (get milestone-completion-rate current-rep) u5))
            (if (< (get milestone-completion-rate current-rep) (var-get reputation-decay-rate)) u0 (- (get milestone-completion-rate current-rep) (var-get reputation-decay-rate))))))
      
      (map-set creator-reputation creator {
        base-score: (get base-score current-rep),
        milestone-completion-rate: new-completion-rate,
        dispute-count: new-dispute-count,
        successful-resolutions: (get successful-resolutions current-rep),
        last-updated: block-height,
        reputation-multiplier: (/ (+ new-completion-rate (- u100 (* new-dispute-count u10))) u2)
      }))))

;; Public Functions

;; Vote on milestone completion
(define-public (vote-on-milestone (campaign-id uint) (milestone-id uint) (vote uint))
  (let ((voting-result (unwrap! (map-get? milestone-voting-results 
          { campaign-id: campaign-id, milestone-id: milestone-id }) ERR_NOT_FOUND))
        (contribution-power (default-to u1 (get voting-power 
          (map-get? contributor-power tx-sender)))))
    
    ;; Validate vote
    (asserts! (<= vote VOTE_ABSTAIN) ERR_INVALID_VOTE)
    (asserts! (< block-height (get voting-deadline voting-result)) ERR_VOTING_ENDED)
    (asserts! (is-none (map-get? milestone-votes 
      { campaign-id: campaign-id, milestone-id: milestone-id, voter: tx-sender })) ERR_ALREADY_VOTED)
    
    ;; Record vote
    (map-set milestone-votes
      { campaign-id: campaign-id, milestone-id: milestone-id, voter: tx-sender }
      {
        vote: vote,
        voting-power: contribution-power,
        voted-at: block-height,
        stake-amount: u0
      })
    
    ;; Update voting results
    (let ((updated-results (merge voting-result {
      yes-votes: (+ (get yes-votes voting-result) (if (is-eq vote VOTE_YES) contribution-power u0)),
      no-votes: (+ (get no-votes voting-result) (if (is-eq vote VOTE_NO) contribution-power u0)),
      abstain-votes: (+ (get abstain-votes voting-result) (if (is-eq vote VOTE_ABSTAIN) contribution-power u0)),
      total-voting-power: (+ (get total-voting-power voting-result) contribution-power)
    })))
      
      (map-set milestone-voting-results
        { campaign-id: campaign-id, milestone-id: milestone-id }
        updated-results))
    
    (ok true)))

;; Initialize milestone voting
(define-public (initialize-milestone-voting (campaign-id uint) (milestone-id uint))
  (let ((voting-deadline (+ block-height (var-get voting-period-blocks))))
    ;; Only contract owner or authorized addresses can initialize voting
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    
    (map-set milestone-voting-results
      { campaign-id: campaign-id, milestone-id: milestone-id }
      {
        yes-votes: u0,
        no-votes: u0,
        abstain-votes: u0,
        total-voting-power: u0,
        voting-deadline: voting-deadline,
        is-approved: false,
        finalized: false
      })
    
    (ok true)))

;; Finalize milestone voting
(define-public (finalize-milestone-voting (campaign-id uint) (milestone-id uint))
  (let ((voting-result (unwrap! (map-get? milestone-voting-results 
          { campaign-id: campaign-id, milestone-id: milestone-id }) ERR_NOT_FOUND)))
    
    ;; Check if voting period ended
    (asserts! (>= block-height (get voting-deadline voting-result)) ERR_VOTING_ENDED)
    (asserts! (not (get finalized voting-result)) ERR_DISPUTE_RESOLVED)
    
    ;; Determine if milestone is approved
    (let ((is-approved (> (get yes-votes voting-result) (get no-votes voting-result)))
          (has-quorum (>= (get total-voting-power voting-result) (var-get min-voting-threshold))))
      
      (map-set milestone-voting-results
        { campaign-id: campaign-id, milestone-id: milestone-id }
        (merge voting-result {
          is-approved: (and is-approved has-quorum),
          finalized: true
        }))
      
      (ok (and is-approved has-quorum)))))

;; Submit a dispute
(define-public (submit-dispute (campaign-id uint) (reason (string-utf8 512)) (evidence-hash (buff 32)))
  (let ((dispute-id (increment-dispute-counter)))
    ;; Anyone can submit a dispute
    (map-set disputes dispute-id {
      campaign-id: campaign-id,
      disputer: tx-sender,
      dispute-reason: reason,
      evidence-hash: evidence-hash,
      created-at: block-height,
      status: DISPUTE_OPEN,
      resolution: u"",
      resolver: tx-sender,
      resolved-at: u0
    })
    
    (ok dispute-id)))

;; Vote on dispute resolution
(define-public (vote-on-dispute (dispute-id uint) (vote uint))
  (let ((dispute-info (unwrap! (map-get? disputes dispute-id) ERR_NOT_FOUND))
        (voting-power (default-to u1 (get voting-power (map-get? contributor-power tx-sender)))))
    
    ;; Validate vote and dispute status
    (asserts! (<= vote VOTE_ABSTAIN) ERR_INVALID_VOTE)
    (asserts! (is-eq (get status dispute-info) DISPUTE_VOTING) ERR_VOTING_ENDED)
    (asserts! (is-none (map-get? dispute-votes { dispute-id: dispute-id, voter: tx-sender })) ERR_ALREADY_VOTED)
    
    ;; Record dispute vote
    (map-set dispute-votes
      { dispute-id: dispute-id, voter: tx-sender }
      {
        vote: vote,
        voted-at: block-height,
        voting-power: voting-power
      })
    
    (ok true)))

;; Resolve dispute
(define-public (resolve-dispute (dispute-id uint) (resolution (string-utf8 512)))
  (let ((dispute-info (unwrap! (map-get? disputes dispute-id) ERR_NOT_FOUND)))
    ;; Only contract owner or community can resolve disputes
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (not (is-eq (get status dispute-info) DISPUTE_RESOLVED)) ERR_DISPUTE_RESOLVED)
    
    ;; Update dispute status
    (map-set disputes dispute-id
      (merge dispute-info {
        status: DISPUTE_RESOLVED,
        resolution: resolution,
        resolver: tx-sender,
        resolved-at: block-height
      }))
    
    (ok true)))

;; Update creator reputation
(define-public (update-creator-reputation (creator principal) (milestone-completed bool) (disputed bool))
  (begin
    ;; Only authorized addresses can update reputation
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    
    (update-reputation-score creator milestone-completed disputed)
    
    (ok true)))

;; Propose governance change
(define-public (propose-governance-change 
  (proposal-type (string-ascii 32))
  (title (string-utf8 256))
  (description (string-utf8 1024))
  (execution-data (buff 128)))
  (let ((proposal-id (increment-proposal-counter))
        (voting-deadline (+ block-height (var-get voting-period-blocks))))
    
    (map-set governance-proposals proposal-id {
      proposal-type: proposal-type,
      title: title,
      description: description,
      proposer: tx-sender,
      created-at: block-height,
      voting-deadline: voting-deadline,
      yes-votes: u0,
      no-votes: u0,
      status: u0, ;; Active
      execution-data: execution-data
    })
    
    (ok proposal-id)))

;; Update contributor voting power
(define-public (update-voting-power (contributor principal) (contribution-amount uint))
  (let ((current-power (default-to 
    { total-contributions: u0, voting-power: u0, reputation-bonus: u0, last-updated: u0 }
    (map-get? contributor-power contributor)))
        (reputation-score (default-to u100 
          (get reputation-multiplier (map-get? creator-reputation contributor)))))
    
    ;; Only authorized contracts can update voting power
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    
    (let ((new-total-contributions (+ (get total-contributions current-power) contribution-amount))
          (new-voting-power (calculate-voting-power new-total-contributions reputation-score)))
      
      (map-set contributor-power contributor {
        total-contributions: new-total-contributions,
        voting-power: new-voting-power,
        reputation-bonus: (/ (* new-voting-power reputation-score) u100),
        last-updated: block-height
      }))
    
    (ok true)))

;; Read-Only Functions

;; Get milestone voting results
(define-read-only (get-voting-results (campaign-id uint) (milestone-id uint))
  (map-get? milestone-voting-results { campaign-id: campaign-id, milestone-id: milestone-id }))

;; Get creator reputation
(define-read-only (get-creator-reputation (creator-address principal))
  (map-get? creator-reputation creator-address))

;; Get dispute information
(define-read-only (get-dispute-info (dispute-id uint))
  (map-get? disputes dispute-id))

;; Get governance proposal
(define-read-only (get-governance-proposal (proposal-id uint))
  (map-get? governance-proposals proposal-id))

;; Get contributor voting power
(define-read-only (get-contributor-power (contributor principal))
  (map-get? contributor-power contributor))

;; Check if user has voted on milestone
(define-read-only (has-voted-on-milestone (campaign-id uint) (milestone-id uint) (voter principal))
  (is-some (map-get? milestone-votes { campaign-id: campaign-id, milestone-id: milestone-id, voter: voter })))

;; Get vote details
(define-read-only (get-milestone-vote (campaign-id uint) (milestone-id uint) (voter principal))
  (map-get? milestone-votes { campaign-id: campaign-id, milestone-id: milestone-id, voter: voter }))

;; Calculate reputation score
(define-read-only (calculate-reputation-score (creator principal))
  (match (map-get? creator-reputation creator)
    reputation-info (get reputation-multiplier reputation-info)
    u100))

;; Get platform governance statistics
(define-read-only (get-governance-stats)
  {
    total-proposals: (var-get proposal-counter),
    total-disputes: (var-get dispute-counter),
    voting-period: (var-get voting-period-blocks),
    min-threshold: (var-get min-voting-threshold)
  })


;; title: governance-controller
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

