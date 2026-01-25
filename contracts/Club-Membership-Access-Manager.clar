(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-already-exists (err u102))
(define-constant err-unauthorized (err u103))
(define-constant err-invalid-tier (err u104))
(define-constant err-expired (err u105))
(define-constant err-insufficient-payment (err u106))
(define-constant err-invalid-duration (err u107))
(define-constant err-self-referral (err u108))
(define-constant err-referrer-not-active (err u109))

(define-constant referral-reward-percent u10)

(define-constant tier-basic u1)
(define-constant tier-premium u2)
(define-constant tier-vip u3)

(define-constant basic-price u100000)
(define-constant premium-price u250000)
(define-constant vip-price u500000)

(define-data-var next-member-id uint u1)
(define-data-var club-name (string-ascii 50) "Elite Club")
(define-data-var membership-fee-basic uint basic-price)
(define-data-var membership-fee-premium uint premium-price)
(define-data-var membership-fee-vip uint vip-price)
(define-data-var total-members uint u0)
(define-data-var club-treasury uint u0)

(define-map members
  { member-id: uint }
  {
    wallet: principal,
    tier: uint,
    expiry-block: uint,
    join-block: uint,
    active: bool,
    access-count: uint
  }
)

(define-map member-by-wallet
  { wallet: principal }
  { member-id: uint }
)

(define-map access-logs
  { member-id: uint, timestamp: uint }
  {
    block-height: uint,
    access-type: (string-ascii 20)
  }
)

(define-map tier-benefits
  { tier: uint }
  {
    name: (string-ascii 20),
    duration-blocks: uint,
    max-guests: uint,
    priority-booking: bool
  }
)

(define-map referral-stats
  { wallet: principal }
  {
    total-referrals: uint,
    total-rewards-earned: uint
  }
)

(define-map referral-records
  { referrer: principal, referred: principal }
  {
    reward-amount: uint,
    block-height: uint
  }
)

(define-private (is-owner)
  (is-eq tx-sender contract-owner)
)

(define-private (get-tier-price (tier uint))
  (if (is-eq tier tier-basic)
    (var-get membership-fee-basic)
    (if (is-eq tier tier-premium)
      (var-get membership-fee-premium)
      (if (is-eq tier tier-vip)
        (var-get membership-fee-vip)
        u0
      )
    )
  )
)

(define-private (get-tier-duration (tier uint))
  (if (is-eq tier tier-basic)
    u2100
    (if (is-eq tier tier-premium)
      u4200
      (if (is-eq tier tier-vip)
        u8400
        u0
      )
    )
  )
)

(define-private (is-valid-tier (tier uint))
  (or (is-eq tier tier-basic)
      (or (is-eq tier tier-premium)
          (is-eq tier tier-vip)
      )
  )
)

(define-private (increment-member-id)
  (let ((current-id (var-get next-member-id)))
    (var-set next-member-id (+ current-id u1))
    current-id
  )
)

(define-public (initialize-tiers)
  (begin
    (asserts! (is-owner) err-owner-only)
    (map-set tier-benefits { tier: tier-basic }
      {
        name: "Basic",
        duration-blocks: u2100,
        max-guests: u1,
        priority-booking: false
      }
    )
    (map-set tier-benefits { tier: tier-premium }
      {
        name: "Premium",
        duration-blocks: u4200,
        max-guests: u3,
        priority-booking: true
      }
    )
    (map-set tier-benefits { tier: tier-vip }
      {
        name: "VIP",
        duration-blocks: u8400,
        max-guests: u5,
        priority-booking: true
      }
    )
    (ok true)
  )
)

(define-public (update-club-settings (new-name (string-ascii 50)) (new-basic-fee uint) (new-premium-fee uint) (new-vip-fee uint))
  (begin
    (asserts! (is-owner) err-owner-only)
    (var-set club-name new-name)
    (var-set membership-fee-basic new-basic-fee)
    (var-set membership-fee-premium new-premium-fee)
    (var-set membership-fee-vip new-vip-fee)
    (ok true)
  )
)

(define-public (register-member (tier uint))
  (let (
    (member-price (get-tier-price tier))
    (member-id (increment-member-id))
    (duration (get-tier-duration tier))
    (expiry (+ stacks-block-height duration))
  )
    (asserts! (is-valid-tier tier) err-invalid-tier)
    (asserts! (is-none (map-get? member-by-wallet { wallet: tx-sender })) err-already-exists)
    (asserts! (>= (stx-get-balance tx-sender) member-price) err-insufficient-payment)
    
    (try! (stx-transfer? member-price tx-sender contract-owner))
    
    (map-set members { member-id: member-id }
      {
        wallet: tx-sender,
        tier: tier,
        expiry-block: expiry,
        join-block: stacks-block-height,
        active: true,
        access-count: u0
      }
    )
    
    (map-set member-by-wallet { wallet: tx-sender } { member-id: member-id })
    (var-set total-members (+ (var-get total-members) u1))
    (var-set club-treasury (+ (var-get club-treasury) member-price))
    
    (ok member-id)
  )
)

(define-public (renew-membership (duration-blocks uint))
  (let (
    (member-data (unwrap! (map-get? member-by-wallet { wallet: tx-sender }) err-not-found))
    (member-id (get member-id member-data))
    (member-info (unwrap! (map-get? members { member-id: member-id }) err-not-found))
    (current-tier (get tier member-info))
    (renewal-price (/ (* (get-tier-price current-tier) duration-blocks) (get-tier-duration current-tier)))
    (new-expiry (+ (get expiry-block member-info) duration-blocks))
  )
    (asserts! (> duration-blocks u0) err-invalid-duration)
    (asserts! (>= (stx-get-balance tx-sender) renewal-price) err-insufficient-payment)
    
    (try! (stx-transfer? renewal-price tx-sender contract-owner))
    
    (map-set members { member-id: member-id }
      (merge member-info { expiry-block: new-expiry })
    )
    
    (var-set club-treasury (+ (var-get club-treasury) renewal-price))
    (ok new-expiry)
  )
)

(define-public (upgrade-membership (new-tier uint))
  (let (
    (member-data (unwrap! (map-get? member-by-wallet { wallet: tx-sender }) err-not-found))
    (member-id (get member-id member-data))
    (member-info (unwrap! (map-get? members { member-id: member-id }) err-not-found))
    (current-tier (get tier member-info))
    (price-diff (- (get-tier-price new-tier) (get-tier-price current-tier)))
  )
    (asserts! (is-valid-tier new-tier) err-invalid-tier)
    (asserts! (> new-tier current-tier) err-invalid-tier)
    (asserts! (>= (stx-get-balance tx-sender) price-diff) err-insufficient-payment)
    
    (if (> price-diff u0)
      (try! (stx-transfer? price-diff tx-sender contract-owner))
      true
    )
    
    (map-set members { member-id: member-id }
      (merge member-info { tier: new-tier })
    )
    
    (if (> price-diff u0)
      (var-set club-treasury (+ (var-get club-treasury) price-diff))
      true
    )
    
    (ok true)
  )
)

(define-public (access-club (access-type (string-ascii 20)))
  (let (
    (member-data (unwrap! (map-get? member-by-wallet { wallet: tx-sender }) err-not-found))
    (member-id (get member-id member-data))
    (member-info (unwrap! (map-get? members { member-id: member-id }) err-not-found))
    (is-expired (> stacks-block-height (get expiry-block member-info)))
  )
    (asserts! (get active member-info) err-unauthorized)
    (asserts! (not is-expired) err-expired)
    
    (map-set access-logs { member-id: member-id, timestamp: stacks-block-height }
      {
        block-height: stacks-block-height,
        access-type: access-type
      }
    )
    
    (map-set members { member-id: member-id }
      (merge member-info { access-count: (+ (get access-count member-info) u1) })
    )
    
    (ok true)
  )
)

(define-public (deactivate-member (member-id uint))
  (let (
    (member-info (unwrap! (map-get? members { member-id: member-id }) err-not-found))
  )
    (asserts! (is-owner) err-owner-only)
    
    (map-set members { member-id: member-id }
      (merge member-info { active: false })
    )
    
    (ok true)
  )
)

(define-public (reactivate-member (member-id uint))
  (let (
    (member-info (unwrap! (map-get? members { member-id: member-id }) err-not-found))
  )
    (asserts! (is-owner) err-owner-only)
    
    (map-set members { member-id: member-id }
      (merge member-info { active: true })
    )
    
    (ok true)
  )
)

(define-public (withdraw-treasury (amount uint))
  (let (
    (current-treasury (var-get club-treasury))
  )
    (asserts! (is-owner) err-owner-only)
    (asserts! (<= amount current-treasury) err-insufficient-payment)
    
    (try! (as-contract (stx-transfer? amount tx-sender contract-owner)))
    (var-set club-treasury (- current-treasury amount))
    
    (ok true)
  )
)

(define-read-only (get-member-info (member-id uint))
  (map-get? members { member-id: member-id })
)

(define-read-only (get-member-by-wallet (wallet principal))
  (match (map-get? member-by-wallet { wallet: wallet })
    member-data (map-get? members { member-id: (get member-id member-data) })
    none
  )
)

(define-read-only (is-member-active (wallet principal))
  (match (get-member-by-wallet wallet)
    member-info
      (and
        (get active member-info)
        (< stacks-block-height (get expiry-block member-info))
      )
    false
  )
)

(define-read-only (get-member-tier (wallet principal))
  (match (get-member-by-wallet wallet)
    member-info (some (get tier member-info))
    none
  )
)

(define-read-only (get-membership-expiry (wallet principal))
  (match (get-member-by-wallet wallet)
    member-info (some (get expiry-block member-info))
    none
  )
)

(define-read-only (get-tier-info (tier uint))
  (map-get? tier-benefits { tier: tier })
)

(define-read-only (get-club-stats)
  {
    total-members: (var-get total-members),
    club-treasury: (var-get club-treasury),
    club-name: (var-get club-name),
    contract-owner: contract-owner
  }
)

(define-read-only (get-tier-pricing)
  {
    basic: (var-get membership-fee-basic),
    premium: (var-get membership-fee-premium),
    vip: (var-get membership-fee-vip)
  }
)

(define-read-only (get-access-log (member-id uint) (timestamp uint))
  (map-get? access-logs { member-id: member-id, timestamp: timestamp })
)

(define-public (register-with-referral (tier uint) (referrer principal))
  (let (
    (member-price (get-tier-price tier))
    (member-id (increment-member-id))
    (duration (get-tier-duration tier))
    (expiry (+ stacks-block-height duration))
    (referrer-active (is-member-active referrer))
    (reward-amount (/ (* member-price referral-reward-percent) u100))
  )
    (asserts! (is-valid-tier tier) err-invalid-tier)
    (asserts! (not (is-eq tx-sender referrer)) err-self-referral)
    (asserts! referrer-active err-referrer-not-active)
    (asserts! (is-none (map-get? member-by-wallet { wallet: tx-sender })) err-already-exists)
    (asserts! (>= (stx-get-balance tx-sender) member-price) err-insufficient-payment)
    
    (try! (stx-transfer? member-price tx-sender contract-owner))
    
    (map-set members { member-id: member-id }
      {
        wallet: tx-sender,
        tier: tier,
        expiry-block: expiry,
        join-block: stacks-block-height,
        active: true,
        access-count: u0
      }
    )
    
    (map-set member-by-wallet { wallet: tx-sender } { member-id: member-id })
    (var-set total-members (+ (var-get total-members) u1))
    (var-set club-treasury (+ (var-get club-treasury) member-price))
    
    (try! (as-contract (stx-transfer? reward-amount tx-sender referrer)))
    
    (map-set referral-records { referrer: referrer, referred: tx-sender }
      {
        reward-amount: reward-amount,
        block-height: stacks-block-height
      }
    )
    
    (match (map-get? referral-stats { wallet: referrer })
      existing-stats
        (map-set referral-stats { wallet: referrer }
          {
            total-referrals: (+ (get total-referrals existing-stats) u1),
            total-rewards-earned: (+ (get total-rewards-earned existing-stats) reward-amount)
          }
        )
      (map-set referral-stats { wallet: referrer }
        {
          total-referrals: u1,
          total-rewards-earned: reward-amount
        }
      )
    )
    
    (ok member-id)
  )
)

(define-read-only (get-referral-stats (wallet principal))
  (default-to
    { total-referrals: u0, total-rewards-earned: u0 }
    (map-get? referral-stats { wallet: wallet })
  )
)

(define-read-only (get-referral-record (referrer principal) (referred principal))
  (map-get? referral-records { referrer: referrer, referred: referred })
)
