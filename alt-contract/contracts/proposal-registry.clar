;; Complete Clarity Smart Contract with Fixed Errors

;; Data Maps
(define-map user-proposals 
  { user: principal, index: uint } 
  { proposal-id: uint })

(define-map user-proposal-counts principal uint)

;; Read-only function to get the number of proposals for a user
(define-read-only (get-user-proposal-count (user principal))
  (default-to u0 (map-get? user-proposal-counts user))
)

;; Private function to increment user proposal count
(define-private (increment-user-proposal-count (user principal))
  (let ((current-count (get-user-proposal-count user)))
    (map-set user-proposal-counts user (+ current-count u1))
    (+ current-count u1)
  )
)

;; Fixed helper function using fold approach (more reliable than recursion)
(define-read-only (get-user-proposals-helper
  (user principal)
  (limit uint)
  (offset uint))
  (let ((user-count (get-user-proposal-count user))
        (max-items (if (> (+ offset limit) user-count) 
                      (- user-count offset) 
                      limit)))
    (if (>= offset user-count)
      (list)
      (get result 
        (fold collect-user-proposal 
              (list u0 u1 u2 u3 u4 u5 u6 u7 u8 u9 u10 u11 u12 u13 u14 u15 u16 u17 u18 u19)
              { user: user, offset: offset, limit: max-items, result: (list) }))
    )
  )
)

;; Helper function for the fold approach
(define-private (collect-user-proposal 
  (index uint)
  (acc { user: principal, offset: uint, limit: uint, result: (list 20 uint) }))
  (let ((current-offset (get offset acc))
        (current-limit (get limit acc))
        (current-result (get result acc))
        (user (get user acc)))
    (if (>= index current-limit)
      acc
      (let ((actual-index (+ current-offset index)))
        (match (map-get? user-proposals { user: user, index: actual-index })
          entry 
            (merge acc { 
              result: (unwrap-panic (as-max-len? 
                        (append current-result (get proposal-id entry)) u20)) 
            })
          acc
        )
      )
    )
  )
)

;; Main public function to get user proposals with pagination
(define-read-only (get-user-proposals 
  (user principal) 
  (limit uint) 
  (offset uint))
  (get-user-proposals-helper user limit offset)
)

;; Public function to add a proposal for a user
(define-public (add-user-proposal (user principal) (proposal-id uint))
  (let ((user-index (get-user-proposal-count user)))
    (map-set user-proposals 
      { user: user, index: user-index } 
      { proposal-id: proposal-id })
    (increment-user-proposal-count user)
    (ok user-index)
  )
)

;; Public function to remove a user proposal
(define-public (remove-user-proposal (user principal) (index uint))
  (let ((user-count (get-user-proposal-count user)))
    (if (< index user-count)
      (begin
        (map-delete user-proposals { user: user, index: index })
        ;; Shift remaining proposals down
        (shift-proposals-down user index user-count)
        ;; Decrement count
        (map-set user-proposal-counts user (- user-count u1))
        (ok true)
      )
      (err u404) ;; Index not found
    )
  )
)

;; Private function to shift proposals down after removal
(define-private (shift-proposals-down (user principal) (removed-index uint) (total-count uint))
  (let ((shift-result (fold shift-proposal-helper
                           (list u0 u1 u2 u3 u4 u5 u6 u7 u8 u9 u10 u11 u12 u13 u14 u15 u16 u17 u18 u19)
                           { user: user, removed-index: removed-index, total-count: total-count, current-index: (+ removed-index u1) })))
    (get current-index shift-result)
  )
)

;; Helper for shifting proposals
(define-private (shift-proposal-helper 
  (iteration uint)
  (acc { user: principal, removed-index: uint, total-count: uint, current-index: uint }))
  (let ((user (get user acc))
        (current-index (get current-index acc))
        (total-count (get total-count acc))
        (target-index (- current-index u1)))
    (if (>= current-index total-count)
      acc
      (match (map-get? user-proposals { user: user, index: current-index })
        entry
          (begin
            (map-set user-proposals 
              { user: user, index: target-index } 
              entry)
            (map-delete user-proposals { user: user, index: current-index })
            (merge acc { current-index: (+ current-index u1) })
          )
        acc
      )
    )
  )
)

;; Read-only function to get a specific user proposal
(define-read-only (get-user-proposal (user principal) (index uint))
  (map-get? user-proposals { user: user, index: index })
)

;; Read-only function to check if user has proposals
(define-read-only (user-has-proposals (user principal))
  (> (get-user-proposal-count user) u0)
)

;; Read-only function to get all proposal IDs for a user (limited to 20)
(define-read-only (get-all-user-proposals (user principal))
  (get-user-proposals user u20 u0)
)

;; Constants for error codes
(define-constant ERR-NOT-FOUND u404)
(define-constant ERR-INVALID-PARAMS u400)
(define-constant ERR-UNAUTHORIZED u401)

;; Public function to get user proposals with validation
(define-public (get-user-proposals-safe 
  (user principal) 
  (limit uint) 
  (offset uint))
  (if (and (<= limit u20) (>= limit u1))
    (ok (get-user-proposals user limit offset))
    (err ERR-INVALID-PARAMS)
  )
)