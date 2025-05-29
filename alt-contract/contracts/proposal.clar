;; AltToken Proposal and Voting Contract

;; Define constants
(define-constant contract-owner tx-sender)
(define-constant err-unauthorized (err u100))
(define-constant err-invalid-proposal (err u101))
(define-constant err-proposal-expired (err u102))
(define-constant err-already-voted (err u103))
(define-constant err-quorum-not-met (err u104))
(define-constant err-balance-error (err u106))
(define-constant quorum-threshold u500) ;; 50% represented as 1000-based percentage
(define-constant voting-period u1440) ;; Voting period in blocks (approximately 10 days)

;; Define data maps
(define-map proposals
  { proposal-id: uint }
  {
    proposer: principal,
    title: (string-ascii 100),
    description: (string-utf8 1000),
    amount: uint,
    recipient: principal,
    votes-for: uint,
    votes-against: uint,
    total-votes: uint,
    status: (string-ascii 20),
    created-at: uint,
    expires-at: uint
  }
)

(define-map votes
  { proposal-id: uint, voter: principal }
  { amount: uint }
)

;; Define data variables
(define-data-var proposal-count uint u0)

;; Contract Functions

;; Submit a new proposal
(define-public (submit-proposal (title (string-ascii 100)) (description (string-utf8 1000)) (amount uint) (recipient principal))
  (let
    (
      (proposal-id (+ (var-get proposal-count) u1))
      (token-balance (unwrap! (contract-call? .alttoken get-balance tx-sender) err-unauthorized))
    )
    (asserts! (> token-balance u0) err-unauthorized)
    (map-set proposals
      { proposal-id: proposal-id }
      {
        proposer: tx-sender,
        title: title,
        description: description,
        amount: amount,
        recipient: recipient,
        votes-for: u0,
        votes-against: u0,
        total-votes: u0,
        status: "active",
        created-at: stacks-block-height,
        expires-at: (+ stacks-block-height voting-period)
      }
    )
    (var-set proposal-count proposal-id)
    (ok proposal-id)
  )
)

;; Vote on a proposal
(define-public (vote (proposal-id uint) (vote-for bool))
  (let
    (
      (proposal (unwrap! (map-get? proposals { proposal-id: proposal-id }) err-invalid-proposal))
      (voting-power (contract-call? .alttoken get-voting-power tx-sender))
    )
    (asserts! (< stacks-block-height (get expires-at proposal)) err-proposal-expired)
    (asserts! (is-none (map-get? votes { proposal-id: proposal-id, voter: tx-sender })) err-already-voted)
    
    (map-set votes { proposal-id: proposal-id, voter: tx-sender } { amount: voting-power })
    
    (map-set proposals { proposal-id: proposal-id }
      (merge proposal {
        votes-for: (if vote-for (+ (get votes-for proposal) voting-power) (get votes-for proposal)),
        votes-against: (if vote-for (get votes-against proposal) (+ (get votes-against proposal) voting-power)),
        total-votes: (+ (get total-votes proposal) voting-power)
      })
    )
    (ok true)
  )
)

;; Finalize a proposal
(define-public (finalize-proposal (proposal-id uint))
  (let
    (
      (proposal (unwrap! (map-get? proposals { proposal-id: proposal-id }) err-invalid-proposal))
      (total-supply (unwrap! (contract-call? .alttoken get-balance (as-contract tx-sender)) err-balance-error))
      (quorum-votes (/ (* total-supply quorum-threshold) u1000))
    )
    (asserts! (>= stacks-block-height (get expires-at proposal)) err-proposal-expired)
    (asserts! (is-eq (get status proposal) "active") err-invalid-proposal)
    (asserts! (>= (get total-votes proposal) quorum-votes) err-quorum-not-met)
    
    (if (> (get votes-for proposal) (get votes-against proposal))
      (begin
        (try! (as-contract (contract-call? .alttoken transfer (get amount proposal) tx-sender (get recipient proposal))))
        (map-set proposals { proposal-id: proposal-id }
          (merge proposal { status: "approved" })
        )
      )
      (map-set proposals { proposal-id: proposal-id }
        (merge proposal { status: "rejected" })
      )
    )
    (ok true)
  )
)

;; Getter Functions

;; Get proposal details
(define-read-only (get-proposal (proposal-id uint))
  (map-get? proposals { proposal-id: proposal-id })
)

;; Get total number of proposals
(define-read-only (get-proposal-count)
  (var-get proposal-count)
)

;; Get vote for a specific proposal and voter
(define-read-only (get-vote (proposal-id uint) (voter principal))
  (map-get? votes { proposal-id: proposal-id, voter: voter })
)
