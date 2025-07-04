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

