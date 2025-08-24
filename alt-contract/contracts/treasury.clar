;; DAO Treasury Management Contract
;; Manages DAO-held STX and SIP-010 tokens with proposal-based governance

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INSUFFICIENT-BALANCE (err u101))
(define-constant ERR-INVALID-AMOUNT (err u102))
(define-constant ERR-TRANSFER-FAILED (err u103))
(define-constant ERR-TOKEN-NOT-SUPPORTED (err u104))
(define-constant ERR-PROPOSAL-NOT-APPROVED (err u105))

;; Contract owner (DAO governance contract)
(define-data-var contract-owner principal tx-sender)

;; Supported SIP-010 tokens mapping
(define-map supported-tokens principal bool)

;; Token balances tracking (for SIP-010 tokens)
(define-map token-balances principal uint)

;; Proposal approvals for transfers
(define-map approved-proposals uint bool)

;; Grant approvals for contributor payments
(define-map approved-grants 
  { recipient: principal, amount: uint, token: (optional principal) }
  bool
)

;; Events
(define-data-var last-event-id uint u0)

;; Authorization check
(define-private (is-authorized (sender principal))
  (or 
    (is-eq sender (var-get contract-owner))
    (is-eq sender (as-contract tx-sender))
  )
)

;; Update contract owner (DAO governance)
(define-public (set-contract-owner (new-owner principal))
  (begin
    (asserts! (is-authorized tx-sender) ERR-NOT-AUTHORIZED)
    (var-set contract-owner new-owner)
    (ok true)
  )
)

;; Add supported SIP-010 token
(define-public (add-supported-token (token-contract principal))
  (begin
    (asserts! (is-authorized tx-sender) ERR-NOT-AUTHORIZED)
    (map-set supported-tokens token-contract true)
    (ok true)
  )
)

;; Remove supported SIP-010 token
(define-public (remove-supported-token (token-contract principal))
  (begin
    (asserts! (is-authorized tx-sender) ERR-NOT-AUTHORIZED)
    (map-delete supported-tokens token-contract)
    (ok true)
  )
)

;; Receive STX - allows contract to hold STX sent to it
(define-public (receive-stx (amount uint))
  (begin
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (var-set last-event-id (+ (var-get last-event-id) u1))
    (print {
      event: "stx-received",
      event-id: (var-get last-event-id),
      amount: amount,
      sender: tx-sender
    })
    (ok amount)
  )
)

;; Transfer STX upon proposal approval
(define-public (transfer-stx (proposal-id uint) (recipient principal) (amount uint))
  (begin
    (asserts! (is-authorized tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    (asserts! (default-to false (map-get? approved-proposals proposal-id)) ERR-PROPOSAL-NOT-APPROVED)
    (asserts! (>= (stx-get-balance (as-contract tx-sender)) amount) ERR-INSUFFICIENT-BALANCE)
    
    (try! (as-contract (stx-transfer? amount tx-sender recipient)))
    
    ;; Remove proposal approval after execution
    (map-delete approved-proposals proposal-id)
    
    (var-set last-event-id (+ (var-get last-event-id) u1))
    (print {
      event: "stx-transferred",
      event-id: (var-get last-event-id),
      proposal-id: proposal-id,
      recipient: recipient,
      amount: amount
    })
    (ok amount)
  )
)

;; Approve proposal for STX transfer
(define-public (approve-proposal (proposal-id uint))
  (begin
    (asserts! (is-authorized tx-sender) ERR-NOT-AUTHORIZED)
    (map-set approved-proposals proposal-id true)
    (ok true)
  )
)

;; Approve grant for contributor payment
(define-public (approve-grant (recipient principal) (amount uint) (token (optional principal)))
  (begin
    (asserts! (is-authorized tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    
    ;; If token is specified, check if it's supported
    (match token
      token-contract (asserts! (default-to false (map-get? supported-tokens token-contract)) ERR-TOKEN-NOT-SUPPORTED)
      true
    )
    
    (map-set approved-grants 
      { recipient: recipient, amount: amount, token: token }
      true
    )
    
    (var-set last-event-id (+ (var-get last-event-id) u1))
    (print {
      event: "grant-approved",
      event-id: (var-get last-event-id),
      recipient: recipient,
      amount: amount,
      token: token
    })
    (ok true)
  )
)

;; Execute approved grant (STX)
(define-public (execute-stx-grant (recipient principal) (amount uint))
  (let (
    (grant-key { recipient: recipient, amount: amount, token: none })
  )
    (asserts! (default-to false (map-get? approved-grants grant-key)) ERR-NOT-AUTHORIZED)
    (asserts! (>= (stx-get-balance (as-contract tx-sender)) amount) ERR-INSUFFICIENT-BALANCE)
    
    (try! (as-contract (stx-transfer? amount tx-sender recipient)))
    
    ;; Remove grant approval after execution
    (map-delete approved-grants grant-key)
    
    (var-set last-event-id (+ (var-get last-event-id) u1))
    (print {
      event: "stx-grant-executed",
      event-id: (var-get last-event-id),
      recipient: recipient,
      amount: amount
    })
    (ok amount)
  )
)

;; Execute approved grant (SIP-010 token)
(define-public (execute-token-grant (recipient principal) (amount uint) (token-contract <sip-010-trait>))
  (let (
    (token-principal (contract-of token-contract))
    (grant-key { recipient: recipient, amount: amount, token: (some token-principal) })
    (current-balance (default-to u0 (map-get? token-balances token-principal)))
  )
    (asserts! (default-to false (map-get? approved-grants grant-key)) ERR-NOT-AUTHORIZED)
    (asserts! (default-to false (map-get? supported-tokens token-principal)) ERR-TOKEN-NOT-SUPPORTED)
    (asserts! (>= current-balance amount) ERR-INSUFFICIENT-BALANCE)
    
    (try! (as-contract (contract-call? token-contract transfer amount tx-sender recipient none)))
    
    ;; Update token balance
    (map-set token-balances token-principal (- current-balance amount))
    
    ;; Remove grant approval after execution
    (map-delete approved-grants grant-key)
    
    (var-set last-event-id (+ (var-get last-event-id) u1))
    (print {
      event: "token-grant-executed",
      event-id: (var-get last-event-id),
      recipient: recipient,
      amount: amount,
      token: token-principal
    })
    (ok amount)
  )
)

;; Deposit SIP-010 token into treasury
(define-public (deposit-token (amount uint) (token-contract <sip-010-trait>))
  (let (
    (token-principal (contract-of token-contract))
    (current-balance (default-to u0 (map-get? token-balances token-principal)))
  )
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    (asserts! (default-to false (map-get? supported-tokens token-principal)) ERR-TOKEN-NOT-SUPPORTED)
    
    (try! (contract-call? token-contract transfer amount tx-sender (as-contract tx-sender) none))
    
    ;; Update token balance
    (map-set token-balances token-principal (+ current-balance amount))
    
    (var-set last-event-id (+ (var-get last-event-id) u1))
    (print {
      event: "token-deposited",
      event-id: (var-get last-event-id),
      amount: amount,
      token: token-principal,
      depositor: tx-sender
    })
    (ok amount)
  )
)

;; Get STX balance of treasury
(define-read-only (get-stx-balance)
  (stx-get-balance (as-contract tx-sender))
)

;; Get SIP-010 token balance of treasury
(define-read-only (get-token-balance (token-contract principal))
  (default-to u0 (map-get? token-balances token-contract))
)

;; Check if token is supported
(define-read-only (is-token-supported (token-contract principal))
  (default-to false (map-get? supported-tokens token-contract))
)

;; Check if proposal is approved
(define-read-only (is-proposal-approved (proposal-id uint))
  (default-to false (map-get? approved-proposals proposal-id))
)

;; Check if grant is approved
(define-read-only (is-grant-approved (recipient principal) (amount uint) (token (optional principal)))
  (default-to false (map-get? approved-grants { recipient: recipient, amount: amount, token: token }))
)

;; Get contract owner
(define-read-only (get-contract-owner)
  (var-get contract-owner)
)

;; Get last event ID
(define-read-only (get-last-event-id)
  (var-get last-event-id)
)

;; Emergency withdrawal (only contract owner)
(define-public (emergency-withdraw-stx (amount uint) (recipient principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    (asserts! (>= (stx-get-balance (as-contract tx-sender)) amount) ERR-INSUFFICIENT-BALANCE)
    
    (try! (as-contract (stx-transfer? amount tx-sender recipient)))
    
    (var-set last-event-id (+ (var-get last-event-id) u1))
    (print {
      event: "emergency-withdrawal",
      event-id: (var-get last-event-id),
      amount: amount,
      recipient: recipient
    })
    (ok amount)
  )
)

;; SIP-010 trait definition for token interactions
(define-trait sip-010-trait
  (
    (transfer (uint principal principal (optional (buff 34))) (response bool uint))
    (get-name () (response (string-ascii 32) uint))
    (get-symbol () (response (string-ascii 32) uint))
    (get-decimals () (response uint uint))
    (get-balance (principal) (response uint uint))
    (get-total-supply () (response uint uint))
    (get-token-uri () (response (optional (string-utf8 256)) uint))
  )
)
