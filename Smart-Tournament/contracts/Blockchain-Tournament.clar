;; Competitive Gaming Tournament Management Smart Contract
;; A decentralized platform for organizing and managing competitive gaming tournaments
;; Features: automated player registration, match orchestration, real-time score tracking, 
;; and merit-based prize distribution with transparent governance

;; ERROR CODE DEFINITIONS

(define-constant ERR-UNAUTHORIZED-ACCESS (err u100))
(define-constant ERR-TOURNAMENT-DOES-NOT-EXIST (err u101))
(define-constant ERR-PLAYER-DUPLICATE-REGISTRATION (err u102))
(define-constant ERR-REGISTRATION-PERIOD-CLOSED (err u103))
(define-constant ERR-MATCH-RECORD-NOT-FOUND (err u104))
(define-constant ERR-MATCH-RESULT-ALREADY-RECORDED (err u105))
(define-constant ERR-TOURNAMENT-CURRENTLY-ACTIVE (err u106))
(define-constant ERR-TOURNAMENT-NOT-IN-ACTIVE-STATE (err u107))
(define-constant ERR-INVALID-PARTICIPANT-ADDRESS (err u108))
(define-constant ERR-INSUFFICIENT-WALLET-BALANCE (err u109))
(define-constant ERR-PRIZE-FUNDS-ALREADY-CLAIMED (err u110))
(define-constant ERR-NOT-ELIGIBLE-FOR-PRIZE-DISTRIBUTION (err u111))
(define-constant ERR-INVALID-TOURNAMENT-PHASE-TRANSITION (err u112))
(define-constant ERR-TOURNAMENT-COMPETITION-FINISHED (err u113))
(define-constant ERR-PLATFORM-EMERGENCY-MAINTENANCE (err u114))
(define-constant ERR-TOURNAMENT-NOT-YET-CONCLUDED (err u115))
(define-constant ERR-INVALID-TIME-RANGE-PARAMETERS (err u120))
(define-constant ERR-START-BLOCK-IN-PAST-TIMELINE (err u121))
(define-constant ERR-INSUFFICIENT-PLAYER-CAPACITY (err u122))
(define-constant ERR-MINIMUM-PLAYER-COUNT-REQUIRED (err u123))
(define-constant ERR-END-BLOCK-HEIGHT-NOT-REACHED (err u124))
(define-constant ERR-INVALID-INPUT-PARAMETERS (err u125))
(define-constant ERR-INVALID-PRINCIPAL-ADDRESS (err u126))
(define-constant ERR-INVALID-STRING-FORMAT (err u127))
(define-constant ERR-INVALID-MATCH-IDENTIFIER (err u128))

;; TOURNAMENT LIFECYCLE CONSTANTS

(define-constant tournament-phase-registration-open u0)
(define-constant tournament-phase-competition-active u1)
(define-constant tournament-phase-results-finalized u2)

;; SCORING AND GAMEPLAY CONSTANTS

(define-constant points-awarded-for-victory u3)
(define-constant points-awarded-for-defeat u0)
(define-constant minimum-required-participants u2)

;; VALIDATION AND SECURITY LIMITS

(define-constant max-tournament-name-length u50)
(define-constant max-tournament-description-length u255)
(define-constant max-allowed-participants u1000)
(define-constant max-entry-fee-amount u1000000000000) ;; 1 million STX maximum
(define-constant max-tournament-duration-blocks u525600) ;; approximately 1 year
(define-constant max-round-number-limit u100)

;; PRIMARY DATA STORAGE STRUCTURES

;; Tournament registry with comprehensive metadata and state tracking
(define-map tournament-registry
  { tournament-identifier: uint }
  {
    tournament-name: (string-ascii 50),
    tournament-description: (string-ascii 255),
    tournament-organizer: principal,
    current-phase: uint,
    registration-fee: uint,
    accumulated-prize-pool: uint,
    competition-start-block: uint,
    competition-end-block: uint,
    maximum-participant-count: uint,
    current-registered-count: uint
  }
)

;; Player performance profiles and tournament participation records
(define-map participant-profiles
  { tournament-identifier: uint, participant-address: principal }
  {
    registration-block-height: uint,
    accumulated-score-points: uint,
    total-matches-participated: uint,
    total-victories-achieved: uint
  }
)

;; Match orchestration records with detailed competition tracking
(define-map competition-match-records
  { tournament-identifier: uint, match-identifier: uint }
  {
    first-competitor: principal,
    second-competitor: principal,
    declared-winner: (optional principal),
    match-completion-block: (optional uint),
    competition-round-number: uint
  }
)

;; Prize distribution claim tracking and verification system
(define-map prize-distribution-claims
  { tournament-identifier: uint, participant-address: principal }
  { 
    claim-status-completed: bool, 
    distributed-prize-amount: uint 
  }
)

;; Tournament-wide scoring aggregation for prize calculations
(define-map tournament-score-aggregates
  { tournament-identifier: uint }
  { 
    total-accumulated-points: uint 
  }
)

;; Match sequence counter for unique identifier generation
(define-map tournament-match-counters
  { tournament-identifier: uint }
  { 
    next-available-match-id: uint 
  }
)

;; GLOBAL CONTRACT STATE VARIABLES

(define-data-var next-tournament-identifier uint u0)
(define-data-var platform-administrator principal tx-sender)
(define-data-var emergency-maintenance-mode bool false)

;; INPUT VALIDATION AND SECURITY FUNCTIONS

;; Validate tournament name meets length and content requirements
(define-private (validate-tournament-name-format (tournament-name (string-ascii 50)))
  (and (> (len tournament-name) u0) (<= (len tournament-name) max-tournament-name-length))
)

;; Validate tournament description meets length requirements
(define-private (validate-tournament-description-format (tournament-description (string-ascii 255)))
  (and (> (len tournament-description) u0) (<= (len tournament-description) max-tournament-description-length))
)

;; Validate entry fee is within acceptable limits
(define-private (validate-entry-fee-amount (fee-amount uint))
  (<= fee-amount max-entry-fee-amount)
)

;; Validate participant capacity is reasonable
(define-private (validate-participant-capacity (capacity-limit uint))
  (and (> capacity-limit u1) (<= capacity-limit max-allowed-participants))
)

;; Validate tournament timeline is logical and within limits
(define-private (validate-tournament-timeline (start-block uint) (end-block uint))
  (and (< start-block end-block) 
       (<= (- end-block start-block) max-tournament-duration-blocks))
)

;; Validate principal address is not the contract itself
(define-private (validate-principal-address (address-to-validate principal))
  (not (is-eq address-to-validate (as-contract tx-sender)))
)

;; Validate tournament exists in registry
(define-private (validate-tournament-exists (tournament-identifier uint))
  (is-some (map-get? tournament-registry { tournament-identifier: tournament-identifier }))
)

;; Validate match exists for specific tournament
(define-private (validate-match-exists (tournament-identifier uint) (match-identifier uint))
  (is-some (map-get? competition-match-records { tournament-identifier: tournament-identifier, match-identifier: match-identifier }))
)

;; Validate round number is within reasonable bounds
(define-private (validate-round-number-bounds (round-number uint))
  (<= round-number max-round-number-limit)
)

;; AUTHORIZATION AND PERMISSION CONTROL FUNCTIONS

;; Verify caller has platform administrator privileges
(define-private (verify-platform-administrator)
  (is-eq tx-sender (var-get platform-administrator))
)

;; Verify caller is the organizer of specific tournament
(define-private (verify-tournament-organizer (tournament-identifier uint))
  (match (map-get? tournament-registry { tournament-identifier: tournament-identifier })
    tournament-data (is-eq tx-sender (get tournament-organizer tournament-data))
    false
  )
)

;; Verify tournament record exists in system
(define-private (verify-tournament-record-exists (tournament-identifier uint))
  (is-some (map-get? tournament-registry { tournament-identifier: tournament-identifier }))
)

;; Verify platform is not in maintenance mode
(define-private (verify-platform-operational-status)
  (not (var-get emergency-maintenance-mode))
)

;; PLATFORM ADMINISTRATION AND GOVERNANCE FUNCTIONS

;; Transfer platform administrator role to new address
(define-public (transfer-platform-administrator-role (new-administrator-address principal))
  (begin
    (asserts! (verify-platform-administrator) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (validate-principal-address new-administrator-address) ERR-INVALID-PRINCIPAL-ADDRESS)
    (ok (var-set platform-administrator new-administrator-address))
  )
)

;; Toggle emergency maintenance mode for platform protection
(define-public (toggle-emergency-maintenance-mode (maintenance-status bool))
  (begin
    (asserts! (verify-platform-administrator) ERR-UNAUTHORIZED-ACCESS)
    (ok (var-set emergency-maintenance-mode maintenance-status))
  )
)

;; TOURNAMENT LIFECYCLE MANAGEMENT FUNCTIONS

;; Create new tournament with comprehensive parameter validation
(define-public (create-new-tournament
    (tournament-name (string-ascii 50))
    (tournament-description (string-ascii 255))
    (registration-fee-amount uint)
    (competition-start-block uint)
    (competition-end-block uint)
    (maximum-participant-limit uint)
  )
  (let (
    (new-tournament-identifier (+ (var-get next-tournament-identifier) u1))
  )
    (asserts! (verify-platform-operational-status) ERR-PLATFORM-EMERGENCY-MAINTENANCE)
    (asserts! (validate-tournament-name-format tournament-name) ERR-INVALID-STRING-FORMAT)
    (asserts! (validate-tournament-description-format tournament-description) ERR-INVALID-STRING-FORMAT)
    (asserts! (validate-entry-fee-amount registration-fee-amount) ERR-INVALID-INPUT-PARAMETERS)
    (asserts! (validate-participant-capacity maximum-participant-limit) ERR-INSUFFICIENT-PLAYER-CAPACITY)
    (asserts! (validate-tournament-timeline competition-start-block competition-end-block) ERR-INVALID-TIME-RANGE-PARAMETERS)
    (asserts! (>= competition-start-block block-height) ERR-START-BLOCK-IN-PAST-TIMELINE)

    (map-set tournament-registry
      { tournament-identifier: new-tournament-identifier }
      {
        tournament-name: tournament-name,
        tournament-description: tournament-description,
        tournament-organizer: tx-sender,
        current-phase: tournament-phase-registration-open,
        registration-fee: registration-fee-amount,
        accumulated-prize-pool: u0,
        competition-start-block: competition-start-block,
        competition-end-block: competition-end-block,
        maximum-participant-count: maximum-participant-limit,
        current-registered-count: u0
      }
    )
    (var-set next-tournament-identifier new-tournament-identifier)
    (ok new-tournament-identifier)
  )
)

;; Register participant for tournament with fee processing
(define-public (register-participant-for-tournament (tournament-identifier uint))
  (let (
    (tournament-data (unwrap! (map-get? tournament-registry { tournament-identifier: tournament-identifier }) ERR-TOURNAMENT-DOES-NOT-EXIST))
    (required-registration-fee (get registration-fee tournament-data))
    (current-participant-count (get current-registered-count tournament-data))
    (maximum-allowed-capacity (get maximum-participant-count tournament-data))
  )
    (asserts! (verify-platform-operational-status) ERR-PLATFORM-EMERGENCY-MAINTENANCE)
    (asserts! (validate-tournament-exists tournament-identifier) ERR-TOURNAMENT-DOES-NOT-EXIST)
    (asserts! (is-eq (get current-phase tournament-data) tournament-phase-registration-open) ERR-REGISTRATION-PERIOD-CLOSED)
    (asserts! (< current-participant-count maximum-allowed-capacity) ERR-REGISTRATION-PERIOD-CLOSED)
    (asserts! (is-none (map-get? participant-profiles { tournament-identifier: tournament-identifier, participant-address: tx-sender })) ERR-PLAYER-DUPLICATE-REGISTRATION)
    
    ;; Process registration fee payment if required
    (if (> required-registration-fee u0)
      (begin
        (unwrap! (stx-transfer? required-registration-fee tx-sender (as-contract tx-sender)) ERR-INSUFFICIENT-WALLET-BALANCE)
        (map-set tournament-registry
          { tournament-identifier: tournament-identifier }
          (merge tournament-data {
            accumulated-prize-pool: (+ (get accumulated-prize-pool tournament-data) required-registration-fee),
            current-registered-count: (+ current-participant-count u1)
          })
        )
      )
      (map-set tournament-registry
        { tournament-identifier: tournament-identifier }
        (merge tournament-data { current-registered-count: (+ current-participant-count u1) })
      )
    )
    
    ;; Initialize participant profile
    (map-set participant-profiles
      { tournament-identifier: tournament-identifier, participant-address: tx-sender }
      {
        registration-block-height: block-height,
        accumulated-score-points: u0,
        total-matches-participated: u0,
        total-victories-achieved: u0
      }
    )
    
    (ok true)
  )
)

;; Transition tournament from registration to active competition phase
(define-public (activate-tournament-competition (tournament-identifier uint))
  (let (
    (tournament-data (unwrap! (map-get? tournament-registry { tournament-identifier: tournament-identifier }) ERR-TOURNAMENT-DOES-NOT-EXIST))
  )
    (asserts! (verify-platform-operational-status) ERR-PLATFORM-EMERGENCY-MAINTENANCE)
    (asserts! (validate-tournament-exists tournament-identifier) ERR-TOURNAMENT-DOES-NOT-EXIST)
    (asserts! (or (verify-platform-administrator) (is-eq tx-sender (get tournament-organizer tournament-data))) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (is-eq (get current-phase tournament-data) tournament-phase-registration-open) ERR-TOURNAMENT-CURRENTLY-ACTIVE)
    (asserts! (>= (get current-registered-count tournament-data) minimum-required-participants) ERR-MINIMUM-PLAYER-COUNT-REQUIRED)
    
    (map-set tournament-registry
      { tournament-identifier: tournament-identifier }
      (merge tournament-data { current-phase: tournament-phase-competition-active })
    )
    
    (ok true)
  )
)

;; Finalize tournament and transition to results phase
(define-public (finalize-tournament-competition (tournament-identifier uint))
  (let (
    (tournament-data (unwrap! (map-get? tournament-registry { tournament-identifier: tournament-identifier }) ERR-TOURNAMENT-DOES-NOT-EXIST))
  )
    (asserts! (verify-platform-operational-status) ERR-PLATFORM-EMERGENCY-MAINTENANCE)
    (asserts! (validate-tournament-exists tournament-identifier) ERR-TOURNAMENT-DOES-NOT-EXIST)
    (asserts! (or (verify-platform-administrator) (is-eq tx-sender (get tournament-organizer tournament-data))) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (is-eq (get current-phase tournament-data) tournament-phase-competition-active) ERR-TOURNAMENT-NOT-IN-ACTIVE-STATE)
    (asserts! (>= block-height (get competition-end-block tournament-data)) ERR-END-BLOCK-HEIGHT-NOT-REACHED)
    
    (map-set tournament-registry
      { tournament-identifier: tournament-identifier }
      (merge tournament-data { current-phase: tournament-phase-results-finalized })
    )
    
    (ok true)
  )
)

;; MATCH ORCHESTRATION AND MANAGEMENT FUNCTIONS

;; Generate unique match identifier for tournament
(define-private (generate-next-match-identifier (tournament-identifier uint))
  (let (
    (counter-record (default-to { next-available-match-id: u0 } (map-get? tournament-match-counters { tournament-identifier: tournament-identifier })))
    (current-match-id (get next-available-match-id counter-record))
    (incremented-match-id (+ current-match-id u1))
  )
    (map-set tournament-match-counters
      { tournament-identifier: tournament-identifier }
      { next-available-match-id: incremented-match-id }
    )
    current-match-id
  )
)

;; Schedule match between two registered participants
(define-public (schedule-competition-match (tournament-identifier uint) (first-competitor principal) (second-competitor principal) (round-number uint))
  (let (
    (tournament-data (unwrap! (map-get? tournament-registry { tournament-identifier: tournament-identifier }) ERR-TOURNAMENT-DOES-NOT-EXIST))
    (generated-match-identifier (generate-next-match-identifier tournament-identifier))
  )
    (asserts! (verify-platform-operational-status) ERR-PLATFORM-EMERGENCY-MAINTENANCE)
    (asserts! (validate-tournament-exists tournament-identifier) ERR-TOURNAMENT-DOES-NOT-EXIST)
    (asserts! (validate-principal-address first-competitor) ERR-INVALID-PRINCIPAL-ADDRESS)
    (asserts! (validate-principal-address second-competitor) ERR-INVALID-PRINCIPAL-ADDRESS)
    (asserts! (validate-round-number-bounds round-number) ERR-INVALID-INPUT-PARAMETERS)
    (asserts! (not (is-eq first-competitor second-competitor)) ERR-INVALID-PARTICIPANT-ADDRESS)
    (asserts! (or (verify-platform-administrator) (is-eq tx-sender (get tournament-organizer tournament-data))) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (is-eq (get current-phase tournament-data) tournament-phase-competition-active) ERR-TOURNAMENT-NOT-IN-ACTIVE-STATE)
    (asserts! (is-some (map-get? participant-profiles { tournament-identifier: tournament-identifier, participant-address: first-competitor })) ERR-INVALID-PARTICIPANT-ADDRESS)
    (asserts! (is-some (map-get? participant-profiles { tournament-identifier: tournament-identifier, participant-address: second-competitor })) ERR-INVALID-PARTICIPANT-ADDRESS)
    
    (map-set competition-match-records
      { tournament-identifier: tournament-identifier, match-identifier: generated-match-identifier }
      {
        first-competitor: first-competitor,
        second-competitor: second-competitor,
        declared-winner: none,
        match-completion-block: none,
        competition-round-number: round-number
      }
    )
    
    (ok generated-match-identifier)
  )
)

;; Record match outcome and update participant statistics
(define-public (record-match-outcome (tournament-identifier uint) (match-identifier uint) (declared-winner principal))
  (let (
    (tournament-data (unwrap! (map-get? tournament-registry { tournament-identifier: tournament-identifier }) ERR-TOURNAMENT-DOES-NOT-EXIST))
    (match-record (unwrap! (map-get? competition-match-records { tournament-identifier: tournament-identifier, match-identifier: match-identifier }) ERR-MATCH-RECORD-NOT-FOUND))
    (first-competitor-address (get first-competitor match-record))
    (second-competitor-address (get second-competitor match-record))
    (first-competitor-profile (unwrap! (map-get? participant-profiles { tournament-identifier: tournament-identifier, participant-address: first-competitor-address }) ERR-INVALID-PARTICIPANT-ADDRESS))
    (second-competitor-profile (unwrap! (map-get? participant-profiles { tournament-identifier: tournament-identifier, participant-address: second-competitor-address }) ERR-INVALID-PARTICIPANT-ADDRESS))
    (current-tournament-total (get-tournament-total-accumulated-score tournament-identifier))
  )
    (asserts! (verify-platform-operational-status) ERR-PLATFORM-EMERGENCY-MAINTENANCE)
    (asserts! (validate-tournament-exists tournament-identifier) ERR-TOURNAMENT-DOES-NOT-EXIST)
    (asserts! (validate-match-exists tournament-identifier match-identifier) ERR-INVALID-MATCH-IDENTIFIER)
    (asserts! (validate-principal-address declared-winner) ERR-INVALID-PRINCIPAL-ADDRESS)
    (asserts! (or (verify-platform-administrator) (is-eq tx-sender (get tournament-organizer tournament-data))) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (is-eq (get current-phase tournament-data) tournament-phase-competition-active) ERR-TOURNAMENT-NOT-IN-ACTIVE-STATE)
    (asserts! (is-none (get declared-winner match-record)) ERR-MATCH-RESULT-ALREADY-RECORDED)
    (asserts! (or (is-eq declared-winner first-competitor-address) (is-eq declared-winner second-competitor-address)) ERR-INVALID-PARTICIPANT-ADDRESS)
    
    ;; Update match record with outcome
    (map-set competition-match-records
      { tournament-identifier: tournament-identifier, match-identifier: match-identifier }
      (merge match-record {
        declared-winner: (some declared-winner),
        match-completion-block: (some block-height)
      })
    )
    
    ;; Update participant statistics based on match outcome
    (if (is-eq declared-winner first-competitor-address)
      (begin
        (map-set participant-profiles
          { tournament-identifier: tournament-identifier, participant-address: first-competitor-address }
          {
            registration-block-height: (get registration-block-height first-competitor-profile),
            accumulated-score-points: (+ (get accumulated-score-points first-competitor-profile) points-awarded-for-victory),
            total-matches-participated: (+ (get total-matches-participated first-competitor-profile) u1),
            total-victories-achieved: (+ (get total-victories-achieved first-competitor-profile) u1)
          }
        )
        (map-set participant-profiles
          { tournament-identifier: tournament-identifier, participant-address: second-competitor-address }
          {
            registration-block-height: (get registration-block-height second-competitor-profile),
            accumulated-score-points: (+ (get accumulated-score-points second-competitor-profile) points-awarded-for-defeat),
            total-matches-participated: (+ (get total-matches-participated second-competitor-profile) u1),
            total-victories-achieved: (get total-victories-achieved second-competitor-profile)
          }
        )
        (map-set tournament-score-aggregates
          { tournament-identifier: tournament-identifier }
          { total-accumulated-points: (+ current-tournament-total points-awarded-for-victory) }
        )
      )
      (begin
        (map-set participant-profiles
          { tournament-identifier: tournament-identifier, participant-address: first-competitor-address }
          {
            registration-block-height: (get registration-block-height first-competitor-profile),
            accumulated-score-points: (+ (get accumulated-score-points first-competitor-profile) points-awarded-for-defeat),
            total-matches-participated: (+ (get total-matches-participated first-competitor-profile) u1),
            total-victories-achieved: (get total-victories-achieved first-competitor-profile)
          }
        )
        (map-set participant-profiles
          { tournament-identifier: tournament-identifier, participant-address: second-competitor-address }
          {
            registration-block-height: (get registration-block-height second-competitor-profile),
            accumulated-score-points: (+ (get accumulated-score-points second-competitor-profile) points-awarded-for-victory),
            total-matches-participated: (+ (get total-matches-participated second-competitor-profile) u1),
            total-victories-achieved: (+ (get total-victories-achieved second-competitor-profile) u1)
          }
        )
        (map-set tournament-score-aggregates
          { tournament-identifier: tournament-identifier }
          { total-accumulated-points: (+ current-tournament-total points-awarded-for-victory) }
        )
      )
    )
    
    (ok true)
  )
)

;; PRIZE DISTRIBUTION AND REWARD SYSTEM FUNCTIONS

;; Retrieve total accumulated score points for tournament
(define-read-only (get-tournament-total-accumulated-score (tournament-identifier uint))
  (get total-accumulated-points (default-to { total-accumulated-points: u0 } (map-get? tournament-score-aggregates { tournament-identifier: tournament-identifier })))
)

;; Calculate participant's proportional share of prize pool
(define-read-only (calculate-participant-prize-share (tournament-identifier uint) (participant-address principal))
  (let (
    (tournament-data (unwrap! (map-get? tournament-registry { tournament-identifier: tournament-identifier }) ERR-TOURNAMENT-DOES-NOT-EXIST))
    (participant-profile (unwrap! (map-get? participant-profiles { tournament-identifier: tournament-identifier, participant-address: participant-address }) ERR-INVALID-PARTICIPANT-ADDRESS))
    (total-prize-pool (get accumulated-prize-pool tournament-data))
    (participant-score (get accumulated-score-points participant-profile))
  )
    (asserts! (is-eq (get current-phase tournament-data) tournament-phase-results-finalized) ERR-TOURNAMENT-NOT-YET-CONCLUDED)
    
    (if (> participant-score u0)
      (let (
        (tournament-total-score (get-tournament-total-accumulated-score tournament-identifier))
        (calculated-prize-amount (/ (* total-prize-pool participant-score) tournament-total-score))
      )
        (ok calculated-prize-amount)
      )
      (ok u0)
    )
  )
)

;; Process prize claim and transfer rewards to participant
(define-public (claim-tournament-prize-reward (tournament-identifier uint))
  (let (
    (tournament-data (unwrap! (map-get? tournament-registry { tournament-identifier: tournament-identifier }) ERR-TOURNAMENT-DOES-NOT-EXIST))
    (participant-profile (unwrap! (map-get? participant-profiles { tournament-identifier: tournament-identifier, participant-address: tx-sender }) ERR-INVALID-PARTICIPANT-ADDRESS))
    (claim-record (default-to { claim-status-completed: false, distributed-prize-amount: u0 } (map-get? prize-distribution-claims { tournament-identifier: tournament-identifier, participant-address: tx-sender })))
    (calculated-prize-amount (unwrap! (calculate-participant-prize-share tournament-identifier tx-sender) ERR-NOT-ELIGIBLE-FOR-PRIZE-DISTRIBUTION))
  )
    (asserts! (verify-platform-operational-status) ERR-PLATFORM-EMERGENCY-MAINTENANCE)
    (asserts! (validate-tournament-exists tournament-identifier) ERR-TOURNAMENT-DOES-NOT-EXIST)
    (asserts! (is-eq (get current-phase tournament-data) tournament-phase-results-finalized) ERR-TOURNAMENT-NOT-YET-CONCLUDED)
    (asserts! (not (get claim-status-completed claim-record)) ERR-PRIZE-FUNDS-ALREADY-CLAIMED)
    (asserts! (> calculated-prize-amount u0) ERR-NOT-ELIGIBLE-FOR-PRIZE-DISTRIBUTION)
    
    (map-set prize-distribution-claims
      { tournament-identifier: tournament-identifier, participant-address: tx-sender }
      { claim-status-completed: true, distributed-prize-amount: calculated-prize-amount }
    )
    
    (unwrap! (as-contract (stx-transfer? calculated-prize-amount (as-contract tx-sender) tx-sender)) ERR-INSUFFICIENT-WALLET-BALANCE)
    
    (ok calculated-prize-amount)
  )
)

;; DATA QUERY AND INFORMATION RETRIEVAL FUNCTIONS

;; Retrieve comprehensive tournament information
(define-read-only (get-tournament-comprehensive-info (tournament-identifier uint))
  (map-get? tournament-registry { tournament-identifier: tournament-identifier })
)

;; Retrieve participant performance profile
(define-read-only (get-participant-performance-profile (tournament-identifier uint) (participant-address principal))
  (map-get? participant-profiles { tournament-identifier: tournament-identifier, participant-address: participant-address })
)

;; Retrieve detailed match information
(define-read-only (get-competition-match-details (tournament-identifier uint) (match-identifier uint))
  (map-get? competition-match-records { tournament-identifier: tournament-identifier, match-identifier: match-identifier })
)

;; Retrieve current match counter value
(define-read-only (get-tournament-match-counter (tournament-identifier uint))
  (get next-available-match-id (default-to { next-available-match-id: u0 } (map-get? tournament-match-counters { tournament-identifier: tournament-identifier })))
)

;; PARTICIPANT MATCH HISTORY AND ANALYTICS FUNCTIONS

;; Verify if participant was involved in specific match
(define-private (participant-involved-in-match (participant-address principal) (match-data {first-competitor: principal, second-competitor: principal, declared-winner: (optional principal), match-completion-block: (optional uint), competition-round-number: uint}))
  (or (is-eq participant-address (get first-competitor match-data))
      (is-eq participant-address (get second-competitor match-data)))
)

;; Retrieve participant's complete match history
(define-read-only (get-participant-match-history (tournament-identifier uint) (participant-address principal))
  (filter-participant-matches tournament-identifier participant-address)
)

;; Filter and compile matches involving specific participant
(define-private (filter-participant-matches (tournament-identifier uint) (participant-address principal))
  (let (
    (match-0 (map-get? competition-match-records { tournament-identifier: tournament-identifier, match-identifier: u0 }))
    (match-1 (map-get? competition-match-records { tournament-identifier: tournament-identifier, match-identifier: u1 }))
    (match-2 (map-get? competition-match-records { tournament-identifier: tournament-identifier, match-identifier: u2 }))
    (match-3 (map-get? competition-match-records { tournament-identifier: tournament-identifier, match-identifier: u3 }))
    (match-4 (map-get? competition-match-records { tournament-identifier: tournament-identifier, match-identifier: u4 }))
    (match-5 (map-get? competition-match-records { tournament-identifier: tournament-identifier, match-identifier: u5 }))
    (match-6 (map-get? competition-match-records { tournament-identifier: tournament-identifier, match-identifier: u6 }))
    (match-7 (map-get? competition-match-records { tournament-identifier: tournament-identifier, match-identifier: u7 }))
    (match-8 (map-get? competition-match-records { tournament-identifier: tournament-identifier, match-identifier: u8 }))
    (match-9 (map-get? competition-match-records { tournament-identifier: tournament-identifier, match-identifier: u9 }))
    
    (results-0 (if (and (is-some match-0) 
                       (participant-involved-in-match participant-address (unwrap-panic match-0)))
                 (list u0)
                 (list)))
    (results-1 (if (and (is-some match-1)
                       (participant-involved-in-match participant-address (unwrap-panic match-1)))
                 (append results-0 u1)
                 results-0))
    (results-2 (if (and (is-some match-2)
                       (participant-involved-in-match participant-address (unwrap-panic match-2)))
                 (append results-1 u2)
                 results-1))
    (results-3 (if (and (is-some match-3)
                       (participant-involved-in-match participant-address (unwrap-panic match-3)))
                 (append results-2 u3)
                 results-2))
    (results-4 (if (and (is-some match-4)
                       (participant-involved-in-match participant-address (unwrap-panic match-4)))
                 (append results-3 u4)
                 results-3))
    (results-5 (if (and (is-some match-5)
                       (participant-involved-in-match participant-address (unwrap-panic match-5)))
                 (append results-4 u5)
                 results-4))
    (results-6 (if (and (is-some match-6)
                       (participant-involved-in-match participant-address (unwrap-panic match-6)))
                 (append results-5 u6)
                 results-5))
    (results-7 (if (and (is-some match-7)
                       (participant-involved-in-match participant-address (unwrap-panic match-7)))
                 (append results-6 u7)
                 results-6))
    (results-8 (if (and (is-some match-8)
                       (participant-involved-in-match participant-address (unwrap-panic match-8)))
                 (append results-7 u8)
                 results-7))
    (final-results (if (and (is-some match-9)
                           (participant-involved-in-match participant-address (unwrap-panic match-9)))
                     (append results-8 u9)
                     results-8))
  )
    final-results
  )
)

;; Calculate participant's tournament ranking position
(define-read-only (calculate-participant-tournament-ranking (tournament-identifier uint) (participant-address principal))
  (let (
    (participant-data (map-get? participant-profiles { tournament-identifier: tournament-identifier, participant-address: participant-address }))
  )
    (match participant-data
      some-data 
        (let (
          (participant-score (get accumulated-score-points some-data))
          (participant-victories (get total-victories-achieved some-data))
          (score-based-rank (/ participant-score u3)) ;; Convert score to rank factor
          (capped-rank (if (> score-based-rank u9) u9 score-based-rank)) ;; Cap at 9
        )
          ;; Simple ranking based on score and victories
          (+ u1 (if (> participant-score u0) 
                  (- u10 capped-rank)  ;; Convert score to ranking position
                  u10))
        )
      u0 ;; Not registered
    )
  )
)

;; Retrieve basic tournament statistics
(define-read-only (get-tournament-statistics (tournament-identifier uint))
  (let (
    (tournament-data (map-get? tournament-registry { tournament-identifier: tournament-identifier }))
  )
    (match tournament-data
      some-tournament (some {
        total-registered: (get current-registered-count some-tournament),
        prize-pool-amount: (get accumulated-prize-pool some-tournament),
        tournament-phase: (get current-phase some-tournament),
        total-score-points: (get-tournament-total-accumulated-score tournament-identifier)
      })
      none
    )
  )
)

;; Get participant win rate calculation
(define-read-only (calculate-participant-win-rate (tournament-identifier uint) (participant-address principal))
  (let (
    (participant-data (map-get? participant-profiles { tournament-identifier: tournament-identifier, participant-address: participant-address }))
  )
    (match participant-data
      some-data
        (let (
          (total-matches (get total-matches-participated some-data))
          (total-wins (get total-victories-achieved some-data))
        )
          (if (> total-matches u0)
            (/ (* total-wins u100) total-matches) ;; Return percentage
            u0
          )
        )
      u0
    )
  )
)

;; CONTRACT INITIALIZATION AND SETUP

(begin
  (var-set platform-administrator tx-sender)
)