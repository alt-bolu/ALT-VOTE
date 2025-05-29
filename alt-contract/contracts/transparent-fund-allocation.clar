
;; title: transparent-fund-allocation
;; version:
;; summary:
;; description:

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-not-authorized (err u100))
(define-constant err-project-not-found (err u101))
(define-constant err-milestone-not-found (err u102))
(define-constant err-insufficient-funds (err u103))
(define-constant err-invalid-amount (err u104))
(define-constant err-milestone-not-approved (err u105))
(define-constant err-escrow-condition-not-met (err u106))

;; Alt Token Contract
;; (use-trait alt-token-trait .alt-token-contract.alt-token-trait)

;; Data maps
(define-map projects
  { project-id: uint }
  {
    owner: principal,
    total-funds: uint,
    disbursed-funds: uint,
    status: (string-ascii 20)
  }
)

(define-map milestones
  { project-id: uint, milestone-id: uint }
  {
    description: (string-ascii 256),
    amount: uint,
    status: (string-ascii 20)
  }
)

(define-map donations
  { project-id: uint, donor: principal }
  { amount: uint }
)

(define-map escrow
  { project-id: uint, donor: principal }
  {
    amount: uint,
    condition: (string-ascii 256)
  }
)

;; Variables
(define-data-var project-nonce uint u0)

;; Functions

;; Create a new project
(define-public (create-project)
  (let
    (
      (new-project-id (+ (var-get project-nonce) u1))
    )
    (map-set projects
      { project-id: new-project-id }
      {
        owner: tx-sender,
        total-funds: u0,
        disbursed-funds: u0,
        status: "active"
      }
    )
    (var-set project-nonce new-project-id)
    (ok new-project-id)
  )
)

;; Release funds from escrow
(define-public (release-escrow (project-id uint) (donor principal))
  (let
    (
      (project (unwrap! (map-get? projects { project-id: project-id }) err-project-not-found))
      (escrow-info (unwrap! (map-get? escrow { project-id: project-id, donor: donor }) err-escrow-condition-not-met))
      (current-donation (default-to { amount: u0 } (map-get? donations { project-id: project-id, donor: donor })))
    )
    (asserts! (is-eq tx-sender (get owner project)) err-not-authorized)
    (map-set projects
      { project-id: project-id }
      (merge project { total-funds: (+ (get total-funds project) (get amount escrow-info)) })
    )
    (map-set donations
      { project-id: project-id, donor: donor }
      { amount: (+ (get amount current-donation) (get amount escrow-info)) }
    )
    (map-delete escrow { project-id: project-id, donor: donor })
    (ok true)
  )
)

;; Approve a milestone
(define-public (approve-milestone (project-id uint) (milestone-id uint))
  (let
    (
      (project (unwrap! (map-get? projects { project-id: project-id }) err-project-not-found))
      (milestone (unwrap! (map-get? milestones { project-id: project-id, milestone-id: milestone-id }) err-milestone-not-found))
    )
    (asserts! (is-eq tx-sender (get owner project)) err-not-authorized)
    (asserts! (>= (- (get total-funds project) (get disbursed-funds project)) (get amount milestone)) err-insufficient-funds)
    (map-set milestones
      { project-id: project-id, milestone-id: milestone-id }
      (merge milestone { status: "approved" })
    )
    (ok true)
  )
)

;; Read-only functions

;; Get project details
(define-read-only (get-project (project-id uint))
  (map-get? projects { project-id: project-id })
)

;; Get milestone details
(define-read-only (get-milestone (project-id uint) (milestone-id uint))
  (map-get? milestones { project-id: project-id, milestone-id: milestone-id })
)

;; Get donation amount for a specific donor and project
(define-read-only (get-donation (project-id uint) (donor principal))
  (map-get? donations { project-id: project-id, donor: donor })
)

;; Get escrow details for a specific donor and project
(define-read-only (get-escrow (project-id uint) (donor principal))
  (map-get? escrow { project-id: project-id, donor: donor })
)

