
;; title: alttoken
;; version:
;; summary:
;; description:

;; AltToken Governance Token Contract

;; Define token
(define-fungible-token alttoken)

;; Define data maps
(define-map balances principal uint)
(define-map staked-balances principal uint)
(define-map proposals uint {
    proposer: principal,
    description: (string-ascii 256),
    votes-for: uint,
    votes-against: uint,
    status: (string-ascii 10)
})

;; Define variables
(define-data-var token-name (string-ascii 32) "AltToken")
(define-data-var token-symbol (string-ascii 10) "ALT")
(define-data-var token-uri (optional (string-utf8 256)) none)
(define-data-var proposal-count uint u0)

;; Error constants
(define-constant err-insufficient-balance (err u100))
(define-constant err-not-token-owner (err u101))
(define-constant err-proposal-not-found (err u102))

;; Token operations

(define-public (mint (amount uint) (recipient principal))
    (begin
        (try! (ft-mint? alttoken amount recipient))
        (ok (map-set balances recipient (+ (default-to u0 (map-get? balances recipient)) amount)))
    )
)

(define-public (burn (amount uint) (owner principal))
    (begin
        (asserts! (is-eq tx-sender owner) err-not-token-owner)
        (try! (ft-burn? alttoken amount owner))
        (ok (map-set balances owner (- (default-to u0 (map-get? balances owner)) amount)))
    )
)

(define-public (transfer (amount uint) (sender principal) (recipient principal))
    (begin
        (asserts! (is-eq tx-sender sender) err-not-token-owner)
        (asserts! (<= amount (default-to u0 (map-get? balances sender))) err-insufficient-balance)
        (try! (ft-transfer? alttoken amount sender recipient))
        (map-set balances sender (- (default-to u0 (map-get? balances sender)) amount))
        (ok (map-set balances recipient (+ (default-to u0 (map-get? balances recipient)) amount)))
    )
)

;; Staking

(define-public (stake (amount uint))
    (begin
        (asserts! (<= amount (default-to u0 (map-get? balances tx-sender))) err-insufficient-balance)
        (map-set balances tx-sender (- (default-to u0 (map-get? balances tx-sender)) amount))
        (ok (map-set staked-balances tx-sender (+ (default-to u0 (map-get? staked-balances tx-sender)) amount)))
    )
)

(define-public (unstake (amount uint))
    (begin
        (asserts! (<= amount (default-to u0 (map-get? staked-balances tx-sender))) err-insufficient-balance)
        (map-set staked-balances tx-sender (- (default-to u0 (map-get? staked-balances tx-sender)) amount))
        (ok (map-set balances tx-sender (+ (default-to u0 (map-get? balances tx-sender)) amount)))
    )
)

;; Voting power

(define-read-only (get-voting-power (user principal))
    (let (
        (balance (default-to u0 (map-get? balances user)))
        (staked-balance (default-to u0 (map-get? staked-balances user)))
    )
    (+ balance (* staked-balance u2))
    )
)

;; Proposal management

(define-public (create-proposal (description (string-ascii 256)))
    (let (
        (proposal-id (+ (var-get proposal-count) u1))
    )
    (map-set proposals proposal-id {
        proposer: tx-sender,
        description: description,
        votes-for: u0,
        votes-against: u0,
        status: "active"
    })
    (var-set proposal-count proposal-id)
    (ok proposal-id)
    )
)

(define-public (vote (proposal-id uint) (vote-for bool))
    (let (
        (proposal (unwrap! (map-get? proposals proposal-id) err-proposal-not-found))
        (voting-power (get-voting-power tx-sender))
    )
    (asserts! (is-eq (get status proposal) "active") (err u103))
    (if vote-for
        (map-set proposals proposal-id (merge proposal { votes-for: (+ (get votes-for proposal) voting-power) }))
        (map-set proposals proposal-id (merge proposal { votes-against: (+ (get votes-against proposal) voting-power) }))
    )
    (ok true)
    )
)

(define-public (close-proposal (proposal-id uint))
    (let (
        (proposal (unwrap! (map-get? proposals proposal-id) err-proposal-not-found))
    )
    (asserts! (is-eq (get status proposal) "active") (err u104))
    (map-set proposals proposal-id (merge proposal {
        status: (if (> (get votes-for proposal) (get votes-against proposal)) "passed" "rejected")
    }))
    (ok true)
    )
)

;; Getter functions

(define-read-only (get-name)
    (ok (var-get token-name))
)

(define-read-only (get-symbol)
    (ok (var-get token-symbol))
)

(define-read-only (get-balance (account principal))
    (ok (default-to u0 (map-get? balances account)))
)

(define-read-only (get-staked-balance (account principal))
    (ok (default-to u0 (map-get? staked-balances account)))
)

(define-read-only (get-proposal (proposal-id uint))
    (ok (unwrap! (map-get? proposals proposal-id) err-proposal-not-found))
)