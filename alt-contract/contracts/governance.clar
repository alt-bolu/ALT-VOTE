;; governance.clar - Core Governance Logic
;; Handles proposal creation, voting, and execution logic

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-UNAUTHORIZED (err u100))
(define-constant ERR-PROPOSAL-NOT-FOUND (err u101))
(define-constant ERR-PROPOSAL-EXPIRED (err u102))
(define-constant ERR-PROPOSAL-NOT-ACTIVE (err u103))
(define-constant ERR-ALREADY-VOTED (err u104))
(define-constant ERR-INSUFFICIENT-BALANCE (err u105))
(define-constant ERR-PROPOSAL-ALREADY-FINALIZED (err u106))
(define-constant ERR-VOTING-STILL-ACTIVE (err u107))
(define-constant ERR-INVALID-THRESHOLD (err u108))
(define-constant ERR-TOKENS-LOCKED (err u109))

;; Data Variables
(define-data-var proposal-counter uint u0)
(define-data-var quorum-threshold uint u20) ;; 20% of total supply
(define-data-var majority-threshold uint u51) ;; 51% majority needed
(define-data-var total-token-supply uint u1000000) ;; Total token supply
(define-data-var voting-period uint u144) ;; ~24 hours in blocks (assuming 10min blocks)

;; Data Maps
(define-map proposals
  { proposal-id: uint }
  {
    proposer: principal,
    title: (string-ascii 100),
    description: (string-ascii 500),
    snapshot-block: uint,
    start-block: uint,
    end-block: uint,
    votes-for: uint,
    votes-against: uint,
    total-votes: uint,
    executed: bool,
    finalized: bool
  }
)

(define-map votes
  { proposal-id: uint, voter: principal }
  {
    vote: bool, ;; true = for, false = against
    power: uint,
    height: uint
  }
)

(define-map user-votes
  { proposal-id: uint, voter: principal }
  bool
)

;; Token balance snapshots at proposal creation
(define-map token-balances
  { user: principal, height: uint }
  uint
)

;; Vote delegation
(define-map delegations
  { delegator: principal }
  { delegate: principal, active: bool }
)

;; Token locks for voting
(define-map token-locks
  { user: principal }
  { locked-amount: uint, unlock-block: uint }
)

;; Read-only functions

;; Get proposal details
(define-read-only (get-proposal-details (proposal-id uint))
  (map-get? proposals { proposal-id: proposal-id })
)

;; Get vote details
(define-read-only (get-vote-details (proposal-id uint) (voter principal))
  (map-get? votes { proposal-id: proposal-id, voter: voter })
)

;; Get proposal outcome
(define-read-only (get-proposal-outcome (proposal-id uint))
  (let ((proposal (unwrap! (map-get? proposals { proposal-id: proposal-id }) (err "Proposal not found"))))
    (if (get finalized proposal)
      (let 
        (
          (total-supply (var-get total-token-supply))
          (quorum-required (/ (* total-supply (var-get quorum-threshold)) u100))
          (votes-for (get votes-for proposal))
          (votes-against (get votes-against proposal))
          (total-votes (get total-votes proposal))
          (majority-required (/ (* total-votes (var-get majority-threshold)) u100))
        )
        (if (>= total-votes quorum-required)
          (if (>= votes-for majority-required)
            (ok "passed")
            (ok "failed"))
          (ok "failed-quorum"))
      )
      (ok "pending")
    )
  )
)

;; Get vote count for a proposal
(define-read-only (get-vote-count (proposal-id uint))
  (let ((proposal (unwrap! (map-get? proposals { proposal-id: proposal-id }) (err "Proposal not found"))))
    (ok {
      votes-for: (get votes-for proposal),
      votes-against: (get votes-against proposal),
      total-votes: (get total-votes proposal)
    })
  )
)

;; Get current thresholds
(define-read-only (get-thresholds)
  {
    quorum-threshold: (var-get quorum-threshold),
    majority-threshold: (var-get majority-threshold)
  }
)

;; Get delegation info
(define-read-only (get-delegation (delegator principal))
  (map-get? delegations { delegator: delegator })
)

;; Get token lock info
(define-read-only (get-token-lock (user principal))
  (map-get? token-locks { user: user })
)

;; Check if user has already voted
(define-read-only (has-voted (proposal-id uint) (voter principal))
  (is-some (map-get? user-votes { proposal-id: proposal-id, voter: voter }))
)

;; Private functions

;; Mock function to get current token balance (in real implementation, this would call token contract)
(define-private (get-current-token-balance (user principal))
  ;; This is a mock - in real implementation, you'd call the token contract
  ;; (contract-call? .token-contract get-balance user)
  u100 ;; Mock balance
)

;; Store token balance snapshot
(define-private (store-balance-snapshot (user principal) (height uint))
  (let ((balance (get-current-token-balance user)))
    (map-set token-balances { user: user, height: stacks-block-height } balance)
    (ok balance)
  )
)

;; Get effective voting power (including delegation)
(define-private (get-voting-power (voter principal) (snapshot-block uint))
  (let 
    (
      (delegation (map-get? delegations { delegator: voter }))
    )
    (if (and (is-some delegation) (get active (unwrap-panic delegation)))
      u0 ;; If delegated, voter has no direct power
        u10
    )
  )
)

;; Public functions

;; Create a new proposal
(define-public (create-proposal (title (string-ascii 100)) (description (string-ascii 500)))
  (let 
    (
      (proposal-id (+ (var-get proposal-counter) u1))
      (current-block stacks-block-height)
      (snapshot-block current-block)
      (start-block (+ current-block u1))
      (end-block (+ start-block (var-get voting-period)))
    )
    ;; Store proposer's balance snapshot
    
    ;; Create proposal
    (map-set proposals
      { proposal-id: proposal-id }
      {
        proposer: tx-sender,
        title: title,
        description: description,
        snapshot-block: snapshot-block,
        start-block: start-block,
        end-block: end-block,
        votes-for: u0,
        votes-against: u0,
        total-votes: u0,
        executed: false,
        finalized: false
      }
    )
    
    ;; Increment counter
    (var-set proposal-counter proposal-id)
    
    (ok proposal-id)
  )
)

;; Vote on a proposal
(define-public (vote-on-proposal (proposal-id uint) (vote bool))
  (let 
    (
      (proposal (unwrap! (map-get? proposals { proposal-id: proposal-id }) ERR-PROPOSAL-NOT-FOUND))
      (current-block stacks-block-height)
      (voter tx-sender)
    )
    ;; Check if proposal is active
    (asserts! (and (>= current-block (get start-block proposal)) 
                   (<= current-block (get end-block proposal))) ERR-PROPOSAL-NOT-ACTIVE)
    
    ;; Check if already voted
    (asserts! (not (has-voted proposal-id voter)) ERR-ALREADY-VOTED)
    
    ;; Store voter's balance snapshot if not exists
    
    ;; Get voting power
    (let ((voting-power (get-voting-power voter (get snapshot-block proposal))))
      (asserts! (> voting-power u0) ERR-INSUFFICIENT-BALANCE)
      
      ;; Lock tokens during voting period (optional feature)
      (map-set token-locks 
        { user: voter }
        { locked-amount: voting-power, unlock-block: (get end-block proposal) }
      )
      
      ;; Record vote
      (map-set votes
        { proposal-id: proposal-id, voter: voter }
        {
          vote: vote,
          power: voting-power,
          height: current-block
        }
      )
      
      ;; Mark as voted
      (map-set user-votes { proposal-id: proposal-id, voter: voter } true)
      
      ;; Update proposal vote counts
      (map-set proposals
        { proposal-id: proposal-id }
        (merge proposal {
          votes-for: (if vote (+ (get votes-for proposal) voting-power) (get votes-for proposal)),
          votes-against: (if vote (get votes-against proposal) (+ (get votes-against proposal) voting-power)),
          total-votes: (+ (get total-votes proposal) voting-power)
        })
      )
      
      (ok true)
    )
  )
)

;; Finalize proposal after voting period ends
(define-public (finalize-proposal (proposal-id uint))
  (let ((proposal (unwrap! (map-get? proposals { proposal-id: proposal-id }) ERR-PROPOSAL-NOT-FOUND)))
    ;; Check if voting period has ended
    (asserts! (> stacks-block-height (get end-block proposal)) ERR-VOTING-STILL-ACTIVE)
    
    ;; Check if not already finalized
    (asserts! (not (get finalized proposal)) ERR-PROPOSAL-ALREADY-FINALIZED)
    
    ;; Mark as finalized
    (map-set proposals
      { proposal-id: proposal-id }
      (merge proposal { finalized: true })
    )
    
    (ok true)
  )
)

;; Set quorum threshold (only contract owner)
(define-public (set-quorum-threshold (new-threshold uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
    (asserts! (and (> new-threshold u0) (<= new-threshold u100)) ERR-INVALID-THRESHOLD)
    (var-set quorum-threshold new-threshold)
    (ok true)
  )
)

;; Set majority threshold (only contract owner)
(define-public (set-majority-threshold (new-threshold uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
    (asserts! (and (> new-threshold u50) (<= new-threshold u100)) ERR-INVALID-THRESHOLD)
    (var-set majority-threshold new-threshold)
    (ok true)
  )
)

;; Delegate voting power
(define-public (delegate-vote (delegate principal))
  (begin
    (asserts! (not (is-eq tx-sender delegate)) ERR-UNAUTHORIZED)
    (map-set delegations
      { delegator: tx-sender }
      { delegate: delegate, active: true }
    )
    (ok true)
  )
)

;; Revoke vote delegation
(define-public (revoke-delegation)
  (begin
    (map-delete delegations { delegator: tx-sender })
    (ok true)
  )
)

;; Vote on behalf of delegator (for delegates)
(define-public (vote-as-delegate (proposal-id uint) (vote bool) (delegator principal))
  (let 
    (
      (delegation (unwrap! (map-get? delegations { delegator: delegator }) ERR-UNAUTHORIZED))
      (proposal (unwrap! (map-get? proposals { proposal-id: proposal-id }) ERR-PROPOSAL-NOT-FOUND))
    )
    ;; Check if caller is the delegate
    (asserts! (and (is-eq tx-sender (get delegate delegation)) (get active delegation)) ERR-UNAUTHORIZED)
    
    ;; Check if proposal is active
    (asserts! (and (>= stacks-block-height (get start-block proposal)) 
                   (<= stacks-block-height (get end-block proposal))) ERR-PROPOSAL-NOT-ACTIVE)
    
    ;; Check if delegator hasn't already voted
    (asserts! (not (has-voted proposal-id delegator)) ERR-ALREADY-VOTED)
    
    ;; Store delegator's balance snapshot
    
    ;; Get delegator's voting power
      
      ;; Record vote for delegator
      (map-set votes
        { proposal-id: proposal-id, voter: delegator }
        {
          vote: vote,
          power: u10,
          height: stacks-block-height
        }
      )
      
      ;; Mark delegator as voted
      (map-set user-votes { proposal-id: proposal-id, voter: delegator } true)
      
      ;; Update proposal vote counts
      (map-set proposals
        { proposal-id: proposal-id }
        (merge proposal {
          votes-for: (if vote (+ (get votes-for proposal) u10) (get votes-for proposal)),
          votes-against: (if vote (get votes-against proposal) (+ (get votes-against proposal) u10)),
          total-votes: (+ (get total-votes proposal) u10)
        })
      )
      
      (ok true)
    )
  )

;; Unlock tokens after voting period
(define-public (unlock-tokens (proposal-id uint))
  (let 
    (
      (proposal (unwrap! (map-get? proposals { proposal-id: proposal-id }) ERR-PROPOSAL-NOT-FOUND))
      (lock-info (map-get? token-locks { user: tx-sender }))
    )
    (asserts! (> stacks-block-height (get end-block proposal)) ERR-VOTING-STILL-ACTIVE)
    (asserts! (is-some lock-info) ERR-TOKENS-LOCKED)
    
    ;; Remove token lock
    (map-delete token-locks { user: tx-sender })
    (ok true)
  )
)