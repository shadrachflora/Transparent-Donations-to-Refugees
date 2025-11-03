(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_INVALID_AMOUNT (err u101))
(define-constant ERR_REFUGEE_NOT_FOUND (err u102))
(define-constant ERR_REFUGEE_ALREADY_EXISTS (err u103))
(define-constant ERR_CAMPAIGN_NOT_FOUND (err u104))
(define-constant ERR_CAMPAIGN_INACTIVE (err u105))
(define-constant ERR_INSUFFICIENT_FUNDS (err u106))
(define-constant ERR_MILESTONE_NOT_FOUND (err u107))
(define-constant ERR_BADGE_ALREADY_EARNED (err u108))

(define-data-var emergency-fund-balance uint u0)
(define-data-var next-emergency-id uint u1)
(define-constant MIN_EMERGENCY_AMOUNT u1000000)
(define-constant EMERGENCY_LOCK_PERIOD u144)

(define-constant TIER_BRONZE u1000000)
(define-constant TIER_SILVER u5000000)
(define-constant TIER_GOLD u10000000)
(define-constant TIER_PLATINUM u25000000)
(define-constant STREAK_BONUS_BLOCKS u1008)
(define-constant MAX_LEADERBOARD_SIZE u100)

(define-constant ERR_SUBSCRIPTION_NOT_FOUND (err u109))
(define-constant ERR_SUBSCRIPTION_INACTIVE (err u110))
(define-constant ERR_SUBSCRIPTION_ALREADY_ACTIVE (err u111))
(define-constant ERR_PAYMENT_NOT_DUE (err u112))

(define-data-var next-subscription-id uint u1)

(define-data-var leaderboard-count uint u0)

(define-data-var next-milestone-id uint u1)

(define-data-var next-refugee-id uint u1)
(define-data-var next-campaign-id uint u1)
(define-data-var total-donations uint u0)

(define-map refugees
  { refugee-id: uint }
  {
    wallet: principal,
    name: (string-ascii 50),
    location: (string-ascii 50),
    story: (string-ascii 200),
    verified: bool,
    total-received: uint,
    created-at: uint
  }
)

(define-map campaigns
  { campaign-id: uint }
  {
    title: (string-ascii 100),
    description: (string-ascii 300),
    target-amount: uint,
    current-amount: uint,
    active: bool,
    created-by: principal,
    created-at: uint
  }
)

(define-map donations
  { donor: principal, refugee-id: uint }
  { amount: uint, timestamp: uint }
)

(define-map campaign-donations
  { donor: principal, campaign-id: uint }
  { amount: uint, timestamp: uint }
)

(define-map refugee-wallet-lookup
  { wallet: principal }
  { refugee-id: uint }
)

(define-read-only (get-refugee (refugee-id uint))
  (map-get? refugees { refugee-id: refugee-id })
)

(define-read-only (get-campaign (campaign-id uint))
  (map-get? campaigns { campaign-id: campaign-id })
)

(define-read-only (get-donation (donor principal) (refugee-id uint))
  (map-get? donations { donor: donor, refugee-id: refugee-id })
)

(define-read-only (get-campaign-donation (donor principal) (campaign-id uint))
  (map-get? campaign-donations { donor: donor, campaign-id: campaign-id })
)

(define-read-only (get-refugee-by-wallet (wallet principal))
  (match (map-get? refugee-wallet-lookup { wallet: wallet })
    lookup-data (get-refugee (get refugee-id lookup-data))
    none
  )
)

(define-read-only (get-total-donations)
  (var-get total-donations)
)

(define-read-only (get-next-refugee-id)
  (var-get next-refugee-id)
)

(define-read-only (get-next-campaign-id)
  (var-get next-campaign-id)
)

(define-public (register-refugee 
  (wallet principal)
  (name (string-ascii 50))
  (location (string-ascii 50))
  (story (string-ascii 200))
)
  (let
    (
      (refugee-id (var-get next-refugee-id))
      (current-stacks-block-height stacks-block-height)
    )
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (is-none (map-get? refugee-wallet-lookup { wallet: wallet })) ERR_REFUGEE_ALREADY_EXISTS)
    
    (map-set refugees
      { refugee-id: refugee-id }
      {
        wallet: wallet,
        name: name,
        location: location,
        story: story,
        verified: false,
        total-received: u0,
        created-at: current-stacks-block-height
      }
    )
    
    (map-set refugee-wallet-lookup
      { wallet: wallet }
      { refugee-id: refugee-id }
    )
    
    (var-set next-refugee-id (+ refugee-id u1))
    (ok refugee-id)
  )
)

(define-public (verify-refugee (refugee-id uint))
  (let
    (
      (refugee-data (unwrap! (map-get? refugees { refugee-id: refugee-id }) ERR_REFUGEE_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    
    (map-set refugees
      { refugee-id: refugee-id }
      (merge refugee-data { verified: true })
    )
    (ok true)
  )
)

(define-public (create-campaign
  (title (string-ascii 100))
  (description (string-ascii 300))
  (target-amount uint)
)
  (let
    (
      (campaign-id (var-get next-campaign-id))
      (current-stacks-block-height stacks-block-height)
    )
    (asserts! (> target-amount u0) ERR_INVALID_AMOUNT)
    
    (map-set campaigns
      { campaign-id: campaign-id }
      {
        title: title,
        description: description,
        target-amount: target-amount,
        current-amount: u0,
        active: true,
        created-by: tx-sender,
        created-at: current-stacks-block-height
      }
    )
    
    (var-set next-campaign-id (+ campaign-id u1))
    (ok campaign-id)
  )
)

(define-public (donate-to-refugee (refugee-id uint) (amount uint))
  (let
    (
      (refugee-data (unwrap! (map-get? refugees { refugee-id: refugee-id }) ERR_REFUGEE_NOT_FOUND))
      (current-stacks-block-height stacks-block-height)
      (existing-donation (default-to { amount: u0, timestamp: u0 } 
        (map-get? donations { donor: tx-sender, refugee-id: refugee-id })))
    )
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (asserts! (get verified refugee-data) ERR_UNAUTHORIZED)
    
    (try! (stx-transfer? amount tx-sender (get wallet refugee-data)))
    
    (map-set donations
      { donor: tx-sender, refugee-id: refugee-id }
      { 
        amount: (+ (get amount existing-donation) amount), 
        timestamp: current-stacks-block-height 
      }
    )
    
    (map-set refugees
      { refugee-id: refugee-id }
      (merge refugee-data { total-received: (+ (get total-received refugee-data) amount) })
    )
    
    (var-set total-donations (+ (var-get total-donations) amount))
    (ok true)
  )
)

(define-public (donate-to-campaign (campaign-id uint) (amount uint))
  (let
    (
      (campaign-data (unwrap! (map-get? campaigns { campaign-id: campaign-id }) ERR_CAMPAIGN_NOT_FOUND))
      (current-stacks-block-height stacks-block-height)
      (existing-donation (default-to { amount: u0, timestamp: u0 } 
        (map-get? campaign-donations { donor: tx-sender, campaign-id: campaign-id })))
    )
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (asserts! (get active campaign-data) ERR_CAMPAIGN_INACTIVE)
    
    (try! (stx-transfer? amount tx-sender (get created-by campaign-data)))
    
    (map-set campaign-donations
      { donor: tx-sender, campaign-id: campaign-id }
      { 
        amount: (+ (get amount existing-donation) amount), 
        timestamp: current-stacks-block-height 
      }
    )
    
    (map-set campaigns
      { campaign-id: campaign-id }
      (merge campaign-data { current-amount: (+ (get current-amount campaign-data) amount) })
    )
    
    (var-set total-donations (+ (var-get total-donations) amount))
    (ok true)
  )
)

(define-public (toggle-campaign-status (campaign-id uint))
  (let
    (
      (campaign-data (unwrap! (map-get? campaigns { campaign-id: campaign-id }) ERR_CAMPAIGN_NOT_FOUND))
    )
    (asserts! (or (is-eq tx-sender CONTRACT_OWNER) (is-eq tx-sender (get created-by campaign-data))) ERR_UNAUTHORIZED)
    
    (map-set campaigns
      { campaign-id: campaign-id }
      (merge campaign-data { active: (not (get active campaign-data)) })
    )
    (ok true)
  )
)

(define-map donation-milestones
  { milestone-id: uint }
  {
    name: (string-ascii 50),
    required-amount: uint,
    badge-title: (string-ascii 30),
    active: bool,
    created-at: uint
  }
)

(define-map donor-total-contributions
  { donor: principal }
  { total-donated: uint, last-updated: uint }
)

(define-map earned-badges
  { donor: principal, milestone-id: uint }
  { earned-at: uint, badge-title: (string-ascii 30) }
)

(define-read-only (get-milestone (milestone-id uint))
  (map-get? donation-milestones { milestone-id: milestone-id })
)

(define-read-only (get-donor-total (donor principal))
  (default-to { total-donated: u0, last-updated: u0 }
    (map-get? donor-total-contributions { donor: donor }))
)

(define-read-only (get-earned-badge (donor principal) (milestone-id uint))
  (map-get? earned-badges { donor: donor, milestone-id: milestone-id })
)

(define-read-only (has-earned-badge (donor principal) (milestone-id uint))
  (is-some (get-earned-badge donor milestone-id))
)

(define-public (create-milestone
  (name (string-ascii 50))
  (required-amount uint)
  (badge-title (string-ascii 30))
)
  (let
    (
      (milestone-id (var-get next-milestone-id))
      (current-height stacks-block-height)
    )
    (asserts! (> required-amount u0) ERR_INVALID_AMOUNT)
    
    (map-set donation-milestones
      { milestone-id: milestone-id }
      {
        name: name,
        required-amount: required-amount,
        badge-title: badge-title,
        active: true,
        created-at: current-height
      }
    )
    
    (var-set next-milestone-id (+ milestone-id u1))
    (ok milestone-id)
  )
)

(define-data-var next-report-id uint u1)

(define-map impact-reports
  { report-id: uint }
  {
    reporter: principal,
    refugee-id: (optional uint),
    campaign-id: (optional uint),
    title: (string-ascii 80),
    description: (string-ascii 400),
    amount-used: uint,
    evidence-hash: (string-ascii 64),
    verified: bool,
    created-at: uint
  }
)

(define-map reporter-stats
  { reporter: principal }
  { total-reports: uint, last-report-time: uint, verified-reports: uint }
)

(define-read-only (get-impact-report (report-id uint))
  (map-get? impact-reports { report-id: report-id })
)

(define-read-only (get-reporter-stats (reporter principal))
  (default-to { total-reports: u0, last-report-time: u0, verified-reports: u0 }
    (map-get? reporter-stats { reporter: reporter }))
)

(define-read-only (calculate-trust-score (reporter principal))
  (let
    ((stats (get-reporter-stats reporter)))
    (if (> (get total-reports stats) u0)
      (/ (* (get verified-reports stats) u100) (get total-reports stats))
      u0))
)

(define-public (submit-impact-report
  (refugee-id (optional uint))
  (campaign-id (optional uint))
  (title (string-ascii 80))
  (description (string-ascii 400))
  (amount-used uint)
  (evidence-hash (string-ascii 64))
)
  (let
    ((report-id (var-get next-report-id))
     (current-time stacks-block-height)
     (reporter-data (get-reporter-stats tx-sender))
     (valid-refugee (if (is-some refugee-id)
                      (is-some (get-refugee (unwrap-panic refugee-id)))
                      true))
     (valid-campaign (if (is-some campaign-id)
                       (is-some (get-campaign (unwrap-panic campaign-id)))
                       true)))
    
    (asserts! (> amount-used u0) ERR_INVALID_AMOUNT)
    (asserts! (> (len title) u0) ERR_INVALID_AMOUNT)
    (asserts! (and valid-refugee valid-campaign) ERR_REFUGEE_NOT_FOUND)
    (asserts! (or (is-some refugee-id) (is-some campaign-id)) ERR_INVALID_AMOUNT)
    
    (map-set impact-reports
      { report-id: report-id }
      {
        reporter: tx-sender,
        refugee-id: refugee-id,
        campaign-id: campaign-id,
        title: title,
        description: description,
        amount-used: amount-used,
        evidence-hash: evidence-hash,
        verified: false,
        created-at: current-time
      })
    
    (map-set reporter-stats
      { reporter: tx-sender }
      {
        total-reports: (+ (get total-reports reporter-data) u1),
        last-report-time: current-time,
        verified-reports: (get verified-reports reporter-data)
      })
    
    (var-set next-report-id (+ report-id u1))
    (ok report-id)))

(define-public (verify-impact-report (report-id uint))
  (let
    ((report-data (unwrap! (get-impact-report report-id) ERR_MILESTONE_NOT_FOUND))
     (reporter (get reporter report-data))
     (reporter-data (get-reporter-stats reporter)))
    
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (not (get verified report-data)) ERR_BADGE_ALREADY_EARNED)
    
    (map-set impact-reports
      { report-id: report-id }
      (merge report-data { verified: true }))
    
    (map-set reporter-stats
      { reporter: reporter }
      (merge reporter-data { verified-reports: (+ (get verified-reports reporter-data) u1) }))
    
    (ok true)))


(define-map emergency-requests
  { emergency-id: uint }
  {
    refugee-id: uint,
    requester: principal,
    amount: uint,
    reason: (string-ascii 200),
    approved: bool,
    withdrawn: bool,
    requested-at: uint,
    approved-at: (optional uint)
  }
)

(define-map emergency-fund-contributions
  { donor: principal }
  { total-contributed: uint, last-contribution: uint }
)

(define-read-only (get-emergency-fund-balance)
  (var-get emergency-fund-balance)
)

(define-read-only (get-emergency-request (emergency-id uint))
  (map-get? emergency-requests { emergency-id: emergency-id })
)

(define-read-only (get-emergency-contribution (donor principal))
  (default-to { total-contributed: u0, last-contribution: u0 }
    (map-get? emergency-fund-contributions { donor: donor }))
)

(define-public (contribute-to-emergency-fund (amount uint))
  (let
    ((current-time stacks-block-height)
     (existing-contribution (get-emergency-contribution tx-sender)))
    
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    
    (map-set emergency-fund-contributions
      { donor: tx-sender }
      {
        total-contributed: (+ (get total-contributed existing-contribution) amount),
        last-contribution: current-time
      })
    
    (var-set emergency-fund-balance (+ (var-get emergency-fund-balance) amount))
    (ok true))
)

(define-public (request-emergency-fund (refugee-id uint) (amount uint) (reason (string-ascii 200)))
  (let
    ((emergency-id (var-get next-emergency-id))
     (refugee-data (unwrap! (get-refugee refugee-id) ERR_REFUGEE_NOT_FOUND))
     (current-time stacks-block-height))
    
    (asserts! (>= amount MIN_EMERGENCY_AMOUNT) ERR_INVALID_AMOUNT)
    (asserts! (<= amount (var-get emergency-fund-balance)) ERR_INSUFFICIENT_FUNDS)
    (asserts! (get verified refugee-data) ERR_UNAUTHORIZED)
    (asserts! (is-eq tx-sender (get wallet refugee-data)) ERR_UNAUTHORIZED)
    
    (map-set emergency-requests
      { emergency-id: emergency-id }
      {
        refugee-id: refugee-id,
        requester: tx-sender,
        amount: amount,
        reason: reason,
        approved: false,
        withdrawn: false,
        requested-at: current-time,
        approved-at: none
      })
    
    (var-set next-emergency-id (+ emergency-id u1))
    (ok emergency-id))
)

(define-public (approve-emergency-request (emergency-id uint))
  (let
    ((request-data (unwrap! (get-emergency-request emergency-id) ERR_MILESTONE_NOT_FOUND))
     (current-time stacks-block-height))
    
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (not (get approved request-data)) ERR_BADGE_ALREADY_EARNED)
    
    (map-set emergency-requests
      { emergency-id: emergency-id }
      (merge request-data { approved: true, approved-at: (some current-time) }))
    
    (ok true))
)

(define-public (withdraw-emergency-fund (emergency-id uint))
  (let
    ((request-data (unwrap! (get-emergency-request emergency-id) ERR_MILESTONE_NOT_FOUND))
     (current-time stacks-block-height)
     (approved-time (unwrap! (get approved-at request-data) ERR_UNAUTHORIZED)))
    
    (asserts! (get approved request-data) ERR_UNAUTHORIZED)
    (asserts! (not (get withdrawn request-data)) ERR_BADGE_ALREADY_EARNED)
    (asserts! (>= current-time (+ approved-time EMERGENCY_LOCK_PERIOD)) ERR_UNAUTHORIZED)
    (asserts! (is-eq tx-sender (get requester request-data)) ERR_UNAUTHORIZED)
    
    (try! (as-contract (stx-transfer? (get amount request-data) tx-sender (get requester request-data))))
    
    (map-set emergency-requests
      { emergency-id: emergency-id }
      (merge request-data { withdrawn: true }))
    
    (var-set emergency-fund-balance (- (var-get emergency-fund-balance) (get amount request-data)))
    (ok true))
)


(define-map donor-leaderboard
  { donor: principal }
  { total-amount: uint, donation-count: uint, current-streak: uint, last-donation-block: uint, tier: uint, rank: uint }
)

(define-map tier-names
  { tier-level: uint }
  { name: (string-ascii 20) }
)

(define-read-only (get-donor-leaderboard-entry (donor principal))
  (default-to { total-amount: u0, donation-count: u0, current-streak: u0, last-donation-block: u0, tier: u0, rank: u0 }
    (map-get? donor-leaderboard { donor: donor }))
)

(define-read-only (calculate-donor-tier (total-amount uint))
  (if (>= total-amount TIER_PLATINUM)
    u4
    (if (>= total-amount TIER_GOLD)
      u3
      (if (>= total-amount TIER_SILVER)
        u2
        (if (>= total-amount TIER_BRONZE)
          u1
          u0))))
)

(define-read-only (get-tier-name (tier-level uint))
  (if (is-eq tier-level u4)
    "Platinum Champion"
    (if (is-eq tier-level u3)
      "Gold Supporter"
      (if (is-eq tier-level u2)
        "Silver Advocate"
        (if (is-eq tier-level u1)
          "Bronze Contributor"
          "Newcomer"))))
)

(define-read-only (is-streak-active (last-block uint))
  (let ((current-block stacks-block-height))
    (<= (- current-block last-block) STREAK_BONUS_BLOCKS))
)

(define-private (update-donor-leaderboard (donor principal) (amount uint))
  (let
    ((entry (get-donor-leaderboard-entry donor))
     (current-block stacks-block-height)
     (new-total (+ (get total-amount entry) amount))
     (new-streak (if (is-streak-active (get last-donation-block entry))
                   (+ (get current-streak entry) u1)
                   u1))
     (new-tier (calculate-donor-tier new-total)))
    
    (map-set donor-leaderboard
      { donor: donor }
      {
        total-amount: new-total,
        donation-count: (+ (get donation-count entry) u1),
        current-streak: new-streak,
        last-donation-block: current-block,
        tier: new-tier,
        rank: u0
      })
    (ok true))
)

(define-map donation-subscriptions
  { subscription-id: uint }
  {
    donor: principal,
    refugee-id: (optional uint),
    campaign-id: (optional uint),
    amount: uint,
    interval-blocks: uint,
    last-payment-block: uint,
    next-payment-block: uint,
    total-payments: uint,
    active: bool,
    created-at: uint
  }
)

(define-map donor-subscriptions
  { donor: principal, index: uint }
  { subscription-id: uint }
)

(define-map donor-subscription-count
  { donor: principal }
  { count: uint }
)

(define-read-only (get-subscription (subscription-id uint))
  (map-get? donation-subscriptions { subscription-id: subscription-id })
)

(define-read-only (get-donor-subscription-count (donor principal))
  (default-to { count: u0 } (map-get? donor-subscription-count { donor: donor }))
)

(define-read-only (is-payment-due (subscription-id uint))
  (match (get-subscription subscription-id)
    sub-data (>= stacks-block-height (get next-payment-block sub-data))
    false)
)

(define-public (create-subscription
  (refugee-id (optional uint))
  (campaign-id (optional uint))
  (amount uint)
  (interval-blocks uint)
)
  (let
    ((subscription-id (var-get next-subscription-id))
     (current-block stacks-block-height)
     (donor-count (get count (get-donor-subscription-count tx-sender))))
    
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (asserts! (> interval-blocks u0) ERR_INVALID_AMOUNT)
    (asserts! (or (is-some refugee-id) (is-some campaign-id)) ERR_INVALID_AMOUNT)
    
    (map-set donation-subscriptions
      { subscription-id: subscription-id }
      {
        donor: tx-sender,
        refugee-id: refugee-id,
        campaign-id: campaign-id,
        amount: amount,
        interval-blocks: interval-blocks,
        last-payment-block: u0,
        next-payment-block: current-block,
        total-payments: u0,
        active: true,
        created-at: current-block
      })
    
    (map-set donor-subscriptions
      { donor: tx-sender, index: donor-count }
      { subscription-id: subscription-id })
    
    (map-set donor-subscription-count
      { donor: tx-sender }
      { count: (+ donor-count u1) })
    
    (var-set next-subscription-id (+ subscription-id u1))
    (ok subscription-id))
)

(define-public (execute-subscription-payment (subscription-id uint))
  (let
    ((sub-data (unwrap! (get-subscription subscription-id) ERR_SUBSCRIPTION_NOT_FOUND))
     (current-block stacks-block-height))
    
    (asserts! (get active sub-data) ERR_SUBSCRIPTION_INACTIVE)
    (asserts! (>= current-block (get next-payment-block sub-data)) ERR_PAYMENT_NOT_DUE)
    
    (if (is-some (get refugee-id sub-data))
      (try! (donate-to-refugee (unwrap-panic (get refugee-id sub-data)) (get amount sub-data)))
      (try! (donate-to-campaign (unwrap-panic (get campaign-id sub-data)) (get amount sub-data))))
    
    (map-set donation-subscriptions
      { subscription-id: subscription-id }
      (merge sub-data {
        last-payment-block: current-block,
        next-payment-block: (+ current-block (get interval-blocks sub-data)),
        total-payments: (+ (get total-payments sub-data) u1)
      }))
    
    (ok true))
)

(define-public (toggle-subscription (subscription-id uint))
  (let
    ((sub-data (unwrap! (get-subscription subscription-id) ERR_SUBSCRIPTION_NOT_FOUND)))
    
    (asserts! (is-eq tx-sender (get donor sub-data)) ERR_UNAUTHORIZED)
    
    (map-set donation-subscriptions
      { subscription-id: subscription-id }
      (merge sub-data { active: (not (get active sub-data)) }))
    
    (ok true))
)