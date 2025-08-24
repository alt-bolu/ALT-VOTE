;; DAO Access Control & Security Contract
;; Implements role-based permissions and progressive decentralization

;; Error constants
(define-constant ERR-UNAUTHORIZED (err u100))
(define-constant ERR-NOT-TOKEN-HOLDER (err u101))
(define-constant ERR-PROPOSAL-NOT-FOUND (err u102))
(define-constant ERR-ALREADY-VOTED (err u103))
(define-constant ERR-VOTING-ENDED (err u104))
(define-constant ERR-INSUFFICIENT-QUORUM (err u105))
(define-constant ERR-INVALID-THRESHOLD (err u106))
(define-constant ERR-CONTRACT-FROZEN (err u107))

;; Contract constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant DAO-CONTRACT (as-contract tx-sender))

;; Data variables
(define-data-var contract-deployer principal CONTRACT-OWNER)
(define-data-var dao-treasury principal CONTRACT-OWNER)
(define-data-var governance-token principal CONTRACT-OWNER)
(define-data-var is-initialized bool false)
(define-data-var is-frozen bool false)

;; Governance parameters
(define-data-var quorum-percentage uint u30) ;; 30% quorum required
(define-data-var approval-threshold uint u51) ;; 51% approval required
(define-data-var voting-duration uint u1008) ;; ~7 days in blocks
(define-data-var min-proposal-deposit uint u1000) ;; Minimum tokens to propose

;; Proposal tracking
(define-data-var next-proposal-id uint u1)

;; Data structures
(define-map proposals
  { proposal-id: uint }
  {
    proposer: principal,
    title: (string-ascii 100),
    description: (string-ascii 500),
    action-type: (string-ascii 20),
    target-contract: (optional principal),
    function-name: (optional (string-ascii 50)),
    parameters: (optional (string-ascii 200)),
    start-block: uint,
    end-block: uint,
    votes-for: uint,
    votes-against: uint,
    total-voters: uint,
    executed: bool,
    deposit-amount: uint
  }
)

(define-map user-votes
  { proposal-id: uint, voter: principal }
  { vote: bool, tokens: uint, block-height: uint }
)

(define-map user-token-balance
  { user: principal }
  { balance: uint, last-updated: uint }
)

;; Role-based permissions
(define-map admin-roles
  { user: principal }
  { 
    deployer-role: bool,
    dao-admin-role: bool,
    mint-permission: bool,
    treasury-permission: bool,
    granted-at: uint
  }
)

;; Read-only functions

(define-read-only (get-contract-info)
  {
    deployer: (var-get contract-deployer),
    dao-contract: DAO-CONTRACT,
    treasury: (var-get dao-treasury),
    governance-token: (var-get governance-token),
    is-initialized: (var-get is-initialized),
    is-frozen: (var-get is-frozen)
  }
)

(define-read-only (get-governance-params)
  {
    quorum-percentage: (var-get quorum-percentage),
    approval-threshold: (var-get approval-threshold),
    voting-duration: (var-get voting-duration),
    min-proposal-deposit: (var-get min-proposal-deposit)
  }
)

(define-read-only (get-proposal (proposal-id uint))
  (map-get? proposals { proposal-id: proposal-id })
)

(define-read-only (get-user-vote (proposal-id uint) (voter principal))
  (map-get? user-votes { proposal-id: proposal-id, voter: voter })
)

(define-read-only (get-user-balance (user principal))
  (default-to u0 (get balance (map-get? user-token-balance { user: user })))
)

(define-read-only (get-user-role (user principal))
  (map-get? admin-roles { user: user })
)

(define-read-only (is-contract-deployer (user principal))
  (or 
    (is-eq user (var-get contract-deployer))
    (default-to false (get deployer-role (map-get? admin-roles { user: user })))
  )
)

(define-read-only (has-dao-admin-role (user principal))
  (or 
    (is-eq user DAO-CONTRACT)
    (default-to false (get dao-admin-role (map-get? admin-roles { user: user })))
  )
)

(define-read-only (can-mint-tokens (user principal))
  (or 
    (has-dao-admin-role user)
    (default-to false (get mint-permission (map-get? admin-roles { user: user })))
  )
)

(define-read-only (can-manage-treasury (user principal))
  (or 
    (has-dao-admin-role user)
    (default-to false (get treasury-permission (map-get? admin-roles { user: user })))
  )
)

(define-read-only (has-voting-power (user principal))
  (> (get-user-balance user) u0)
)

(define-read-only (calculate-voting-power (user principal))
  (let ((balance (get-user-balance user)))
    (if (> balance u0) balance u0)
  )
)

(define-read-only (get-proposal-status (proposal-id uint))
  (match (get-proposal proposal-id)
    proposal
    (let 
      (
        (current-block stacks-block-height)
        (end-block (get end-block proposal))
        (votes-for (get votes-for proposal))
        (votes-against (get votes-against proposal))
        (total-votes (+ votes-for votes-against))
        (total-supply (get-total-token-supply))
        (quorum-needed (/ (* total-supply (var-get quorum-percentage)) u100))
        (approval-needed (/ (* total-votes (var-get approval-threshold)) u100))
      )
      {
        status: (if (get executed proposal) "executed"
                  (if (>= current-block end-block) 
                    (if (>= total-votes quorum-needed)
                      (if (>= votes-for approval-needed) "passed" "rejected")
                      "failed-quorum")
                    "active")),
        votes-for: votes-for,
        votes-against: votes-against,
        total-votes: total-votes,
        quorum-reached: (>= total-votes quorum-needed),
        approval-reached: (>= votes-for approval-needed),
        blocks-remaining: (if (>= current-block end-block) u0 (- end-block current-block))
      }
    )
    { status: "not-found", votes-for: u0, votes-against: u0, total-votes: u0, 
      quorum-reached: false, approval-reached: false, blocks-remaining: u0 }
  )
)

;; Private functions

(define-private (get-total-token-supply)
  ;; This would integrate with your token contract
  ;; For now, we'll use a placeholder calculation
  u1000000
)

;; Admin functions (Contract Deployer only)

(define-public (initialize-dao 
  (treasury principal) 
  (token-contract principal)
  (initial-quorum uint)
  (initial-threshold uint))
  (begin
    (asserts! (is-contract-deployer tx-sender) ERR-UNAUTHORIZED)
    (asserts! (not (var-get is-initialized)) ERR-UNAUTHORIZED)
    (asserts! (and (>= initial-quorum u1) (<= initial-quorum u100)) ERR-INVALID-THRESHOLD)
    (asserts! (and (>= initial-threshold u1) (<= initial-threshold u100)) ERR-INVALID-THRESHOLD)
    
    (var-set dao-treasury treasury)
    (var-set governance-token token-contract)
    (var-set quorum-percentage initial-quorum)
    (var-set approval-threshold initial-threshold)
    (var-set is-initialized true)
    
    ;; Grant initial roles to deployer
    (map-set admin-roles 
      { user: tx-sender }
      { 
        deployer-role: true,
        dao-admin-role: true,
        mint-permission: true,
        treasury-permission: true,
        granted-at: stacks-block-height
      }
    )
    
    (ok true)
  )
)

(define-public (update-governance-params 
  (new-quorum uint) 
  (new-threshold uint) 
  (new-duration uint)
  (new-min-deposit uint))
  (begin
    (asserts! (not (var-get is-frozen)) ERR-CONTRACT-FROZEN)
    (asserts! (has-dao-admin-role tx-sender) ERR-UNAUTHORIZED)
    (asserts! (and (>= new-quorum u1) (<= new-quorum u100)) ERR-INVALID-THRESHOLD)
    (asserts! (and (>= new-threshold u1) (<= new-threshold u100)) ERR-INVALID-THRESHOLD)
    
    (var-set quorum-percentage new-quorum)
    (var-set approval-threshold new-threshold)
    (var-set voting-duration new-duration)
    (var-set min-proposal-deposit new-min-deposit)
    
    (ok true)
  )
)

(define-public (grant-role 
  (user principal) 
  (deployer-role bool)
  (dao-admin-role bool) 
  (mint-permission bool) 
  (treasury-permission bool))
  (begin
    (asserts! (not (var-get is-frozen)) ERR-CONTRACT-FROZEN)
    (asserts! (is-contract-deployer tx-sender) ERR-UNAUTHORIZED)
    
    (map-set admin-roles 
      { user: user }
      { 
        deployer-role: deployer-role,
        dao-admin-role: dao-admin-role,
        mint-permission: mint-permission,
        treasury-permission: treasury-permission,
        granted-at: stacks-block-height
      }
    )
    
    (ok true)
  )
)

(define-public (revoke-role (user principal))
  (begin
    (asserts! (not (var-get is-frozen)) ERR-CONTRACT-FROZEN)
    (asserts! (is-contract-deployer tx-sender) ERR-UNAUTHORIZED)
    (asserts! (not (is-eq user (var-get contract-deployer))) ERR-UNAUTHORIZED)
    
    (map-delete admin-roles { user: user })
    (ok true)
  )
)

;; Progressive decentralization - transfer deployer role to DAO
(define-public (transfer-deployer-to-dao)
  (begin
    (asserts! (is-contract-deployer tx-sender) ERR-UNAUTHORIZED)
    (var-set contract-deployer DAO-CONTRACT)
    
    ;; Grant DAO contract all admin privileges
    (map-set admin-roles 
      { user: DAO-CONTRACT }
      { 
        deployer-role: true,
        dao-admin-role: true,
        mint-permission: true,
        treasury-permission: true,
        granted-at: stacks-block-height
      }
    )
    
    (ok true)
  )
)

;; Proposal functions

(define-public (submit-proposal 
  (title (string-ascii 100))
  (description (string-ascii 500))
  (action-type (string-ascii 20))
  (target-contract (optional principal))
  (function-name (optional (string-ascii 50)))
  (parameters (optional (string-ascii 200)))
  (deposit-amount uint))
  (let 
    (
      (proposal-id (var-get next-proposal-id))
      (user-balance (get-user-balance tx-sender))
    )
    (asserts! (not (var-get is-frozen)) ERR-CONTRACT-FROZEN)
    (asserts! (> user-balance u0) ERR-NOT-TOKEN-HOLDER)
    (asserts! (>= deposit-amount (var-get min-proposal-deposit)) ERR-UNAUTHORIZED)
    (asserts! (>= user-balance deposit-amount) ERR-NOT-TOKEN-HOLDER)
    
    (map-set proposals
      { proposal-id: proposal-id }
      {
        proposer: tx-sender,
        title: title,
        description: description,
        action-type: action-type,
        target-contract: target-contract,
        function-name: function-name,
        parameters: parameters,
        start-block: stacks-block-height,
        end-block: (+ stacks-block-height (var-get voting-duration)),
        votes-for: u0,
        votes-against: u0,
        total-voters: u0,
        executed: false,
        deposit-amount: deposit-amount
      }
    )
    
    ;; Lock proposer's tokens as deposit
    (map-set user-token-balance
      { user: tx-sender }
      { 
        balance: (- user-balance deposit-amount),
        last-updated: stacks-block-height
      }
    )
    
    (var-set next-proposal-id (+ proposal-id u1))
    (ok proposal-id)
  )
)

(define-public (vote-on-proposal (proposal-id uint) (vote-for bool))
  (let 
    (
      (proposal (unwrap! (get-proposal proposal-id) ERR-PROPOSAL-NOT-FOUND))
      (user-balance (get-user-balance tx-sender))
      (existing-vote (get-user-vote proposal-id tx-sender))
    )
    (asserts! (not (var-get is-frozen)) ERR-CONTRACT-FROZEN)
    (asserts! (> user-balance u0) ERR-NOT-TOKEN-HOLDER)
    (asserts! (is-none existing-vote) ERR-ALREADY-VOTED)
    (asserts! (<= stacks-block-height (get end-block proposal)) ERR-VOTING-ENDED)
    
    ;; Record the vote
    (map-set user-votes
      { proposal-id: proposal-id, voter: tx-sender }
      { vote: vote-for, tokens: user-balance, block-height: stacks-block-height }
    )
    
    ;; Update proposal vote counts
    (map-set proposals
      { proposal-id: proposal-id }
      (merge proposal
        (if vote-for
          { votes-for: (+ (get votes-for proposal) user-balance), votes-against: (get votes-against proposal) }
          { votes-for: (get votes-for proposal), votes-against: (+ (get votes-against proposal) user-balance) }
        )
      )
    )
    
    (ok true)
  )
)

;; Treasury management functions

(define-public (execute-treasury-action (proposal-id uint))
  (let 
    (
      (proposal (unwrap! (get-proposal proposal-id) ERR-PROPOSAL-NOT-FOUND))
      (proposal-status (get-proposal-status proposal-id))
    )
    (asserts! (not (var-get is-frozen)) ERR-CONTRACT-FROZEN)
    (asserts! (can-manage-treasury tx-sender) ERR-UNAUTHORIZED)
    (asserts! (is-eq (get status proposal-status) "passed") ERR-UNAUTHORIZED)
    (asserts! (not (get executed proposal)) ERR-UNAUTHORIZED)
    
    ;; Mark as executed
    (map-set proposals
      { proposal-id: proposal-id }
      (merge proposal { executed: true })
    )
    
    ;; Return deposit to proposer
    (let ((proposer (get proposer proposal))
          (deposit (get deposit-amount proposal))
          (current-balance (get-user-balance proposer)))
      (map-set user-token-balance
        { user: proposer }
        { 
          balance: (+ current-balance deposit),
          last-updated: stacks-block-height
        }
      )
    )
    
    (ok true)
  )
)

;; Token management functions (DAO-controlled)

(define-public (mint-tokens (recipient principal) (amount uint))
  (begin
    (asserts! (not (var-get is-frozen)) ERR-CONTRACT-FROZEN)
    (asserts! (can-mint-tokens tx-sender) ERR-UNAUTHORIZED)
    
    (let ((current-balance (get-user-balance recipient)))
      (map-set user-token-balance
        { user: recipient }
        { 
          balance: (+ current-balance amount),
          last-updated: stacks-block-height
        }
      )
    )
    
    (ok true)
  )
)

(define-public (update-user-balance (user principal) (new-balance uint))
  (begin
    (asserts! (not (var-get is-frozen)) ERR-CONTRACT-FROZEN)
    (asserts! (has-dao-admin-role tx-sender) ERR-UNAUTHORIZED)
    
    (map-set user-token-balance
      { user: user }
      { 
        balance: new-balance,
        last-updated: stacks-block-height
      }
    )
    
    (ok true)
  )
)

;; Emergency functions

(define-public (freeze-contract)
  (begin
    (asserts! (is-contract-deployer tx-sender) ERR-UNAUTHORIZED)
    (var-set is-frozen true)
    (ok true)
  )
)

(define-public (unfreeze-contract)
  (begin
    (asserts! (is-contract-deployer tx-sender) ERR-UNAUTHORIZED)
    (var-set is-frozen false)
    (ok true)
  )
)