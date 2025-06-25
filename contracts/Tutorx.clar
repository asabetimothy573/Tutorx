(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_TUTOR_NOT_FOUND (err u101))
(define-constant ERR_STUDENT_NOT_FOUND (err u102))
(define-constant ERR_SESSION_NOT_FOUND (err u103))
(define-constant ERR_INSUFFICIENT_FUNDS (err u104))
(define-constant ERR_SESSION_ALREADY_COMPLETED (err u105))
(define-constant ERR_SESSION_NOT_COMPLETED (err u106))
(define-constant ERR_TUTOR_NOT_VERIFIED (err u107))
(define-constant ERR_INVALID_RATING (err u108))
(define-constant ERR_ALREADY_RATED (err u109))
(define-constant ERR_SESSION_ALREADY_PAID (err u110))

(define-data-var next-tutor-id uint u1)
(define-data-var next-session-id uint u1)
(define-data-var platform-fee-percentage uint u5)

(define-map tutors
  { tutor-id: uint }
  {
    address: principal,
    name: (string-ascii 50),
    subject: (string-ascii 30),
    hourly-rate: uint,
    total-sessions: uint,
    total-earnings: uint,
    average-rating: uint,
    rating-count: uint,
    verified: bool,
    active: bool
  }
)

(define-map tutor-addresses
  { address: principal }
  { tutor-id: uint }
)

(define-map sessions
  { session-id: uint }
  {
    tutor-id: uint,
    student: principal,
    duration-hours: uint,
    total-cost: uint,
    platform-fee: uint,
    tutor-payment: uint,
    status: (string-ascii 20),
    created-at: uint,
    completed-at: (optional uint),
    paid: bool,
    student-rating: (optional uint),
    tutor-rating: (optional uint)
  }
)

(define-map student-sessions
  { student: principal, session-id: uint }
  { exists: bool }
)

(define-map tutor-sessions
  { tutor-id: uint, session-id: uint }
  { exists: bool }
)

(define-public (register-tutor (name (string-ascii 50)) (subject (string-ascii 30)) (hourly-rate uint))
  (let
    (
      (tutor-id (var-get next-tutor-id))
    )
    (asserts! (is-none (map-get? tutor-addresses { address: tx-sender })) ERR_NOT_AUTHORIZED)
    (map-set tutors
      { tutor-id: tutor-id }
      {
        address: tx-sender,
        name: name,
        subject: subject,
        hourly-rate: hourly-rate,
        total-sessions: u0,
        total-earnings: u0,
        average-rating: u0,
        rating-count: u0,
        verified: false,
        active: true
      }
    )
    (map-set tutor-addresses { address: tx-sender } { tutor-id: tutor-id })
    (var-set next-tutor-id (+ tutor-id u1))
    (ok tutor-id)
  )
)

(define-public (verify-tutor (tutor-id uint))
  (let
    (
      (tutor (unwrap! (map-get? tutors { tutor-id: tutor-id }) ERR_TUTOR_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (map-set tutors
      { tutor-id: tutor-id }
      (merge tutor { verified: true })
    )
    (ok true)
  )
)

(define-public (book-session (tutor-id uint) (duration-hours uint))
  (let
    (
      (tutor (unwrap! (map-get? tutors { tutor-id: tutor-id }) ERR_TUTOR_NOT_FOUND))
      (session-id (var-get next-session-id))
      (total-cost (* (get hourly-rate tutor) duration-hours))
      (platform-fee (/ (* total-cost (var-get platform-fee-percentage)) u100))
      (tutor-payment (- total-cost platform-fee))
    )
    (asserts! (get verified tutor) ERR_TUTOR_NOT_VERIFIED)
    (asserts! (get active tutor) ERR_NOT_AUTHORIZED)
    (try! (stx-transfer? total-cost tx-sender (as-contract tx-sender)))
    (map-set sessions
      { session-id: session-id }
      {
        tutor-id: tutor-id,
        student: tx-sender,
        duration-hours: duration-hours,
        total-cost: total-cost,
        platform-fee: platform-fee,
        tutor-payment: tutor-payment,
        status: "booked",
        created-at: stacks-block-height,
        completed-at: none,
        paid: false,
        student-rating: none,
        tutor-rating: none
      }
    )
    (map-set student-sessions { student: tx-sender, session-id: session-id } { exists: true })
    (map-set tutor-sessions { tutor-id: tutor-id, session-id: session-id } { exists: true })
    (var-set next-session-id (+ session-id u1))
    (ok session-id)
  )
)

(define-public (complete-session (session-id uint))
  (let
    (
      (session (unwrap! (map-get? sessions { session-id: session-id }) ERR_SESSION_NOT_FOUND))
      (tutor (unwrap! (map-get? tutors { tutor-id: (get tutor-id session) }) ERR_TUTOR_NOT_FOUND))
    )
    (asserts! (or (is-eq tx-sender (get student session)) (is-eq tx-sender (get address tutor))) ERR_NOT_AUTHORIZED)
    (asserts! (is-eq (get status session) "booked") ERR_SESSION_ALREADY_COMPLETED)
    (map-set sessions
      { session-id: session-id }
      (merge session {
        status: "completed",
        completed-at: (some stacks-block-height)
      })
    )
    (ok true)
  )
)

(define-public (pay-tutor (session-id uint))
  (let
    (
      (session (unwrap! (map-get? sessions { session-id: session-id }) ERR_SESSION_NOT_FOUND))
      (tutor (unwrap! (map-get? tutors { tutor-id: (get tutor-id session) }) ERR_TUTOR_NOT_FOUND))
    )
    (asserts! (is-eq (get status session) "completed") ERR_SESSION_NOT_COMPLETED)
    (asserts! (not (get paid session)) ERR_SESSION_ALREADY_PAID)
    (try! (as-contract (stx-transfer? (get tutor-payment session) tx-sender (get address tutor))))
    (map-set sessions
      { session-id: session-id }
      (merge session { paid: true })
    )
    (map-set tutors
      { tutor-id: (get tutor-id session) }
      (merge tutor {
        total-sessions: (+ (get total-sessions tutor) u1),
        total-earnings: (+ (get total-earnings tutor) (get tutor-payment session))
      })
    )
    (ok true)
  )
)

(define-public (rate-session (session-id uint) (rating uint) (is-student bool))
  (let
    (
      (session (unwrap! (map-get? sessions { session-id: session-id }) ERR_SESSION_NOT_FOUND))
      (tutor (unwrap! (map-get? tutors { tutor-id: (get tutor-id session) }) ERR_TUTOR_NOT_FOUND))
    )
    (asserts! (and (>= rating u1) (<= rating u5)) ERR_INVALID_RATING)
    (asserts! (is-eq (get status session) "completed") ERR_SESSION_NOT_COMPLETED)
    (if is-student
      (begin
        (asserts! (is-eq tx-sender (get student session)) ERR_NOT_AUTHORIZED)
        (asserts! (is-none (get student-rating session)) ERR_ALREADY_RATED)
        (map-set sessions
          { session-id: session-id }
          (merge session { student-rating: (some rating) })
        )
        (let
          (
            (new-rating-count (+ (get rating-count tutor) u1))
            (new-total-rating (+ (* (get average-rating tutor) (get rating-count tutor)) rating))
            (new-average (/ new-total-rating new-rating-count))
          )
          (map-set tutors
            { tutor-id: (get tutor-id session) }
            (merge tutor {
              average-rating: new-average,
              rating-count: new-rating-count
            })
          )
        )
      )
      (begin
        (asserts! (is-eq tx-sender (get address tutor)) ERR_NOT_AUTHORIZED)
        (asserts! (is-none (get tutor-rating session)) ERR_ALREADY_RATED)
        (map-set sessions
          { session-id: session-id }
          (merge session { tutor-rating: (some rating) })
        )
      )
    )
    (ok true)
  )
)

(define-public (update-tutor-rate (new-rate uint))
  (let
    (
      (tutor-data (unwrap! (map-get? tutor-addresses { address: tx-sender }) ERR_TUTOR_NOT_FOUND))
      (tutor (unwrap! (map-get? tutors { tutor-id: (get tutor-id tutor-data) }) ERR_TUTOR_NOT_FOUND))
    )
    (map-set tutors
      { tutor-id: (get tutor-id tutor-data) }
      (merge tutor { hourly-rate: new-rate })
    )
    (ok true)
  )
)

(define-public (toggle-tutor-status)
  (let
    (
      (tutor-data (unwrap! (map-get? tutor-addresses { address: tx-sender }) ERR_TUTOR_NOT_FOUND))
      (tutor (unwrap! (map-get? tutors { tutor-id: (get tutor-id tutor-data) }) ERR_TUTOR_NOT_FOUND))
    )
    (map-set tutors
      { tutor-id: (get tutor-id tutor-data) }
      (merge tutor { active: (not (get active tutor)) })
    )
    (ok (not (get active tutor)))
  )
)

(define-public (set-platform-fee (new-fee uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (asserts! (<= new-fee u20) ERR_NOT_AUTHORIZED)
    (var-set platform-fee-percentage new-fee)
    (ok true)
  )
)

(define-public (withdraw-platform-fees (amount uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (try! (as-contract (stx-transfer? amount tx-sender CONTRACT_OWNER)))
    (ok true)
  )
)

(define-read-only (get-tutor (tutor-id uint))
  (map-get? tutors { tutor-id: tutor-id })
)

(define-read-only (get-tutor-by-address (address principal))
  (match (map-get? tutor-addresses { address: address })
    tutor-data (map-get? tutors { tutor-id: (get tutor-id tutor-data) })
    none
  )
)

(define-read-only (get-session (session-id uint))
  (map-get? sessions { session-id: session-id })
)

(define-read-only (get-platform-fee)
  (var-get platform-fee-percentage)
)

(define-read-only (get-next-tutor-id)
  (var-get next-tutor-id)
)

(define-read-only (get-next-session-id)
  (var-get next-session-id)
)

(define-read-only (calculate-session-cost (tutor-id uint) (duration-hours uint))
  (match (map-get? tutors { tutor-id: tutor-id })
    tutor (let
      (
        (total-cost (* (get hourly-rate tutor) duration-hours))
        (platform-fee (/ (* total-cost (var-get platform-fee-percentage)) u100))
      )
      (ok {
        total-cost: total-cost,
        platform-fee: platform-fee,
        tutor-payment: (- total-cost platform-fee)
      })
    )
    ERR_TUTOR_NOT_FOUND
  )
)

(define-read-only (get-contract-balance)
  (stx-get-balance (as-contract tx-sender))
)