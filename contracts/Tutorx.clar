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
(define-constant ERR_SUBJECT_NOT_FOUND (err u111))
(define-constant ERR_PREREQUISITE_NOT_MET (err u112))
(define-constant ERR_INVALID_DIFFICULTY (err u113))
(define-constant ERR_INVALID_CATEGORY (err u114))
(define-constant ERR_SUBJECT_ALREADY_EXISTS (err u115))
(define-constant ERR_CIRCULAR_DEPENDENCY (err u116))

(define-data-var next-tutor-id uint u1)
(define-data-var next-session-id uint u1)
(define-data-var platform-fee-percentage uint u5)
(define-data-var next-subject-id uint u1)

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

(define-map subjects
  { subject-id: uint }
  {
    name: (string-ascii 50),
    category: (string-ascii 30),
    description: (string-ascii 200),
    difficulty-level: uint,
    creator-tutor-id: uint,
    total-enrollments: uint,
    average-rating: uint,
    rating-count: uint,
    created-at: uint,
    active: bool
  }
)

(define-map subject-prerequisites
  { subject-id: uint, prerequisite-id: uint }
  { required: bool }
)

(define-map tutor-subject-specializations
  { tutor-id: uint, subject-id: uint }
  { 
    proficiency-level: uint,
    years-experience: uint,
    certification: bool
  }
)

(define-map student-subject-progress
  { student: principal, subject-id: uint }
  {
    completion-percentage: uint,
    sessions-completed: uint,
    current-difficulty: uint,
    last-session-at: uint,
    passed-assessment: bool
  }
)

(define-map subject-categories
  { category: (string-ascii 30) }
  { 
    subject-count: uint,
    total-enrollments: uint
  }
)

(define-map learning-paths
  { path-id: uint }
  {
    name: (string-ascii 50),
    creator-tutor-id: uint,
    subject-sequence: (list 10 uint),
    estimated-duration: uint,
    difficulty-progression: (list 10 uint),
    enrollments: uint,
    created-at: uint
  }
)

(define-map student-learning-paths
  { student: principal, path-id: uint }
  {
    current-position: uint,
    progress-percentage: uint,
    started-at: uint,
    estimated-completion: uint
  }
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

(define-public (create-subject (name (string-ascii 50)) (category (string-ascii 30)) (description (string-ascii 200)) (difficulty-level uint))
  (let
    (
      (subject-id (var-get next-subject-id))
      (tutor-data (unwrap! (map-get? tutor-addresses { address: tx-sender }) ERR_TUTOR_NOT_FOUND))
      (tutor (unwrap! (map-get? tutors { tutor-id: (get tutor-id tutor-data) }) ERR_TUTOR_NOT_FOUND))
    )
    (asserts! (get verified tutor) ERR_TUTOR_NOT_VERIFIED)
    (asserts! (and (>= difficulty-level u1) (<= difficulty-level u5)) ERR_INVALID_DIFFICULTY)
    (asserts! (> (len category) u0) ERR_INVALID_CATEGORY)
    (map-set subjects
      { subject-id: subject-id }
      {
        name: name,
        category: category,
        description: description,
        difficulty-level: difficulty-level,
        creator-tutor-id: (get tutor-id tutor-data),
        total-enrollments: u0,
        average-rating: u0,
        rating-count: u0,
        created-at: stacks-block-height,
        active: true
      }
    )
    (match (map-get? subject-categories { category: category })
      existing-category (map-set subject-categories
        { category: category }
        { 
          subject-count: (+ (get subject-count existing-category) u1),
          total-enrollments: (get total-enrollments existing-category)
        }
      )
      (map-set subject-categories
        { category: category }
        {
          subject-count: u1,
          total-enrollments: u0
        }
      )
    )
    (var-set next-subject-id (+ subject-id u1))
    (ok subject-id)
  )
)

(define-public (add-subject-prerequisite (subject-id uint) (prerequisite-id uint))
  (let
    (
      (subject (unwrap! (map-get? subjects { subject-id: subject-id }) ERR_SUBJECT_NOT_FOUND))
      (prerequisite (unwrap! (map-get? subjects { subject-id: prerequisite-id }) ERR_SUBJECT_NOT_FOUND))
      (tutor-data (unwrap! (map-get? tutor-addresses { address: tx-sender }) ERR_TUTOR_NOT_FOUND))
    )
    (asserts! (is-eq (get creator-tutor-id subject) (get tutor-id tutor-data)) ERR_NOT_AUTHORIZED)
    (asserts! (not (is-eq subject-id prerequisite-id)) ERR_CIRCULAR_DEPENDENCY)
    (asserts! (<= (get difficulty-level prerequisite) (get difficulty-level subject)) ERR_INVALID_DIFFICULTY)
    (map-set subject-prerequisites
      { subject-id: subject-id, prerequisite-id: prerequisite-id }
      { required: true }
    )
    (ok true)
  )
)

(define-public (add-tutor-specialization (subject-id uint) (proficiency-level uint) (years-experience uint) (certification bool))
  (let
    (
      (subject (unwrap! (map-get? subjects { subject-id: subject-id }) ERR_SUBJECT_NOT_FOUND))
      (tutor-data (unwrap! (map-get? tutor-addresses { address: tx-sender }) ERR_TUTOR_NOT_FOUND))
      (tutor (unwrap! (map-get? tutors { tutor-id: (get tutor-id tutor-data) }) ERR_TUTOR_NOT_FOUND))
    )
    (asserts! (get verified tutor) ERR_TUTOR_NOT_VERIFIED)
    (asserts! (and (>= proficiency-level u1) (<= proficiency-level u5)) ERR_INVALID_DIFFICULTY)
    (map-set tutor-subject-specializations
      { tutor-id: (get tutor-id tutor-data), subject-id: subject-id }
      {
        proficiency-level: proficiency-level,
        years-experience: years-experience,
        certification: certification
      }
    )
    (ok true)
  )
)

(define-public (enroll-in-subject (subject-id uint))
  (let
    (
      (subject (unwrap! (map-get? subjects { subject-id: subject-id }) ERR_SUBJECT_NOT_FOUND))
      (existing-progress (map-get? student-subject-progress { student: tx-sender, subject-id: subject-id }))
    )
    (asserts! (get active subject) ERR_NOT_AUTHORIZED)
    (asserts! (is-none existing-progress) ERR_ALREADY_RATED)
    (try! (check-prerequisites subject-id tx-sender))
    (map-set student-subject-progress
      { student: tx-sender, subject-id: subject-id }
      {
        completion-percentage: u0,
        sessions-completed: u0,
        current-difficulty: u1,
        last-session-at: stacks-block-height,
        passed-assessment: false
      }
    )
    (map-set subjects
      { subject-id: subject-id }
      (merge subject { total-enrollments: (+ (get total-enrollments subject) u1) })
    )
    (let
      (
        (category-data (unwrap! (map-get? subject-categories { category: (get category subject) }) ERR_INVALID_CATEGORY))
      )
      (map-set subject-categories
        { category: (get category subject) }
        (merge category-data { total-enrollments: (+ (get total-enrollments category-data) u1) })
      )
    )
    (ok true)
  )
)

(define-public (update-subject-progress (subject-id uint) (completion-percentage uint) (passed-assessment bool))
  (let
    (
      (progress (unwrap! (map-get? student-subject-progress { student: tx-sender, subject-id: subject-id }) ERR_SUBJECT_NOT_FOUND))
      (subject (unwrap! (map-get? subjects { subject-id: subject-id }) ERR_SUBJECT_NOT_FOUND))
    )
    (asserts! (<= completion-percentage u100) ERR_INVALID_DIFFICULTY)
    (map-set student-subject-progress
      { student: tx-sender, subject-id: subject-id }
      (merge progress {
        completion-percentage: completion-percentage,
        sessions-completed: (+ (get sessions-completed progress) u1),
        last-session-at: stacks-block-height,
        passed-assessment: passed-assessment
      })
    )
    (ok true)
  )
)

(define-public (rate-subject (subject-id uint) (rating uint))
  (let
    (
      (subject (unwrap! (map-get? subjects { subject-id: subject-id }) ERR_SUBJECT_NOT_FOUND))
      (progress (unwrap! (map-get? student-subject-progress { student: tx-sender, subject-id: subject-id }) ERR_SUBJECT_NOT_FOUND))
    )
    (asserts! (and (>= rating u1) (<= rating u5)) ERR_INVALID_RATING)
    (asserts! (>= (get completion-percentage progress) u80) ERR_SESSION_NOT_COMPLETED)
    (let
      (
        (new-rating-count (+ (get rating-count subject) u1))
        (new-total-rating (+ (* (get average-rating subject) (get rating-count subject)) rating))
        (new-average (/ new-total-rating new-rating-count))
      )
      (map-set subjects
        { subject-id: subject-id }
        (merge subject {
          average-rating: new-average,
          rating-count: new-rating-count
        })
      )
    )
    (ok true)
  )
)

(define-public (create-learning-path (name (string-ascii 50)) (subject-sequence (list 10 uint)) (estimated-duration uint))
  (let
    (
      (path-id (var-get next-subject-id))
      (tutor-data (unwrap! (map-get? tutor-addresses { address: tx-sender }) ERR_TUTOR_NOT_FOUND))
      (tutor (unwrap! (map-get? tutors { tutor-id: (get tutor-id tutor-data) }) ERR_TUTOR_NOT_FOUND))
      (difficulty-list (map get-subject-difficulty subject-sequence))
    )
    (asserts! (get verified tutor) ERR_TUTOR_NOT_VERIFIED)
    (asserts! (> (len subject-sequence) u0) ERR_INVALID_DIFFICULTY)
    (try! (validate-subject-sequence subject-sequence))
    (map-set learning-paths
      { path-id: path-id }
      {
        name: name,
        creator-tutor-id: (get tutor-id tutor-data),
        subject-sequence: subject-sequence,
        estimated-duration: estimated-duration,
        difficulty-progression: difficulty-list,
        enrollments: u0,
        created-at: stacks-block-height
      }
    )
    (var-set next-subject-id (+ path-id u1))
    (ok path-id)
  )
)

(define-public (enroll-in-learning-path (path-id uint))
  (let
    (
      (path (unwrap! (map-get? learning-paths { path-id: path-id }) ERR_SUBJECT_NOT_FOUND))
      (existing-enrollment (map-get? student-learning-paths { student: tx-sender, path-id: path-id }))
    )
    (asserts! (is-none existing-enrollment) ERR_ALREADY_RATED)
    (map-set student-learning-paths
      { student: tx-sender, path-id: path-id }
      {
        current-position: u0,
        progress-percentage: u0,
        started-at: stacks-block-height,
        estimated-completion: (+ stacks-block-height (get estimated-duration path))
      }
    )
    (map-set learning-paths
      { path-id: path-id }
      (merge path { enrollments: (+ (get enrollments path) u1) })
    )
    (ok true)
  )
)

(define-private (check-prerequisites (subject-id uint) (student principal))
  (let
    (
      (prerequisites (get-subject-prerequisites subject-id))
    )
    (if (is-eq (len prerequisites) u0)
      (ok true)
      (match (fold check-single-prerequisite prerequisites (ok student))
        success (ok true)
        error-val (err error-val)
      )
    )
  )
)

(define-private (check-single-prerequisite (prerequisite-id uint) (acc (response principal uint)))
  (match acc
    student (let
      (
        (progress (map-get? student-subject-progress { student: student, subject-id: prerequisite-id }))
      )
      (match progress
        existing-progress (if (>= (get completion-percentage existing-progress) u80)
          (ok student)
          ERR_PREREQUISITE_NOT_MET
        )
        ERR_PREREQUISITE_NOT_MET
      )
    )
    error-val (err error-val)
  )
)

(define-private (validate-subject-sequence (sequence (list 10 uint)))
  (fold validate-subject-exists sequence (ok true))
)

(define-private (validate-subject-exists (subject-id uint) (acc (response bool uint)))
  (match acc
    success (match (map-get? subjects { subject-id: subject-id })
      subject (ok true)
      ERR_SUBJECT_NOT_FOUND
    )
    error-val (err error-val)
  )
)

(define-private (get-subject-difficulty (subject-id uint))
  (match (map-get? subjects { subject-id: subject-id })
    subject (get difficulty-level subject)
    u0
  )
)

(define-private (get-subject-prerequisites (subject-id uint))
  (let
    (
      (prereq-1 (if (is-some (map-get? subject-prerequisites { subject-id: subject-id, prerequisite-id: u1 })) (list u1) (list)))
      (prereq-2 (if (is-some (map-get? subject-prerequisites { subject-id: subject-id, prerequisite-id: u2 })) (concat prereq-1 (list u2)) prereq-1))
      (prereq-3 (if (is-some (map-get? subject-prerequisites { subject-id: subject-id, prerequisite-id: u3 })) (concat prereq-2 (list u3)) prereq-2))
      (prereq-4 (if (is-some (map-get? subject-prerequisites { subject-id: subject-id, prerequisite-id: u4 })) (concat prereq-3 (list u4)) prereq-3))
      (prereq-5 (if (is-some (map-get? subject-prerequisites { subject-id: subject-id, prerequisite-id: u5 })) (concat prereq-4 (list u5)) prereq-4))
    )
    prereq-5
  )
)

(define-read-only (get-subject (subject-id uint))
  (map-get? subjects { subject-id: subject-id })
)

(define-read-only (get-subject-prerequisites-info (subject-id uint))
  (get-subject-prerequisites subject-id)
)

(define-read-only (get-tutor-specialization (tutor-id uint) (subject-id uint))
  (map-get? tutor-subject-specializations { tutor-id: tutor-id, subject-id: subject-id })
)

(define-read-only (get-student-progress (student principal) (subject-id uint))
  (map-get? student-subject-progress { student: student, subject-id: subject-id })
)

(define-read-only (get-category-stats (category (string-ascii 30)))
  (map-get? subject-categories { category: category })
)

(define-read-only (get-learning-path (path-id uint))
  (map-get? learning-paths { path-id: path-id })
)

(define-read-only (get-student-path-progress (student principal) (path-id uint))
  (map-get? student-learning-paths { student: student, path-id: path-id })
)

(define-read-only (get-next-subject-id)
  (var-get next-subject-id)
)

(define-read-only (check-subject-eligibility (student principal) (subject-id uint))
  (let
    (
      (subject (map-get? subjects { subject-id: subject-id }))
      (existing-progress (map-get? student-subject-progress { student: student, subject-id: subject-id }))
    )
    (match subject
      sub (if (is-none existing-progress)
        (is-ok (check-prerequisites subject-id student))
        false
      )
      false
    )
  )
)