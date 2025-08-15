;; contracts/garden-registry.clar
;; Simple Flower Garden Tour - Garden Registry Contract

(define-constant ERR-NOT-FOUND (err u404))
(define-constant ERR-UNAUTHORIZED (err u401))
(define-constant ERR-INVALID-INPUT (err u400))

(define-data-var garden-counter uint u0)

(define-map gardens
    { garden-id: uint }
    {
        owner: principal,
        name: (string-ascii 100),
        location: (string-ascii 200),
        description: (string-ascii 500),
        visit-schedule: (string-ascii 200),
        active: bool,
        created-at: uint
    }
)

(define-map garden-plants
    { garden-id: uint, plant-id: uint }
    {
        plant-name: (string-ascii 50),
        bloom-season: (string-ascii 20),
        care-tips: (string-ascii 300)
    }
)

(define-data-var plant-counter uint u0)

(define-public (register-garden (name (string-ascii 100))
                               (location (string-ascii 200))
                               (description (string-ascii 500))
                               (visit-schedule (string-ascii 200)))
    (let ((garden-id (+ (var-get garden-counter) u1)))
        (map-set gardens
            { garden-id: garden-id }
            {
                owner: tx-sender,
                name: name,
                location: location,
                description: description,
                visit-schedule: visit-schedule,
                active: true,
                created-at: stacks-block-height
            }
        )
        (var-set garden-counter garden-id)
        (ok garden-id)
    )
)

(define-public (add-plant (garden-id uint)
                         (plant-name (string-ascii 50))
                         (bloom-season (string-ascii 20))
                         (care-tips (string-ascii 300)))
    (let ((garden-data (unwrap! (map-get? gardens { garden-id: garden-id }) ERR-NOT-FOUND))
          (plant-id (+ (var-get plant-counter) u1)))
        (asserts! (is-eq (get owner garden-data) tx-sender) ERR-UNAUTHORIZED)
        (map-set garden-plants
            { garden-id: garden-id, plant-id: plant-id }
            {
                plant-name: plant-name,
                bloom-season: bloom-season,
                care-tips: care-tips
            }
        )
        (var-set plant-counter plant-id)
        (ok plant-id)
    )
)

(define-public (update-visit-schedule (garden-id uint) (new-schedule (string-ascii 200)))
    (let ((garden-data (unwrap! (map-get? gardens { garden-id: garden-id }) ERR-NOT-FOUND)))
        (asserts! (is-eq (get owner garden-data) tx-sender) ERR-UNAUTHORIZED)
        (map-set gardens
            { garden-id: garden-id }
            (merge garden-data { visit-schedule: new-schedule })
        )
        (ok true)
    )
)

(define-read-only (get-garden (garden-id uint))
    (map-get? gardens { garden-id: garden-id })
)

(define-read-only (get-plant-info (garden-id uint) (plant-id uint))
    (map-get? garden-plants { garden-id: garden-id, plant-id: plant-id })
)

(define-read-only (get-garden-count)
    (var-get garden-counter)
)

;; contracts/garden-tours.clar
;; Garden Tour Scheduling and Management

(define-constant ERR-TOUR-NOT-FOUND (err u404))
(define-constant ERR-TOUR-UNAUTHORIZED (err u401))
(define-constant ERR-TOUR-FULL (err u409))

(define-data-var tour-counter uint u0)

(define-map tours
    { tour-id: uint }
    {
        garden-id: uint,
        guide: principal,
        tour-date: uint,
        max-visitors: uint,
        current-visitors: uint,
        description: (string-ascii 300),
        active: bool
    }
)

(define-map tour-bookings
    { tour-id: uint, visitor: principal }
    { booked-at: uint }
)

(define-public (create-tour (garden-id uint)
                           (tour-date uint)
                           (max-visitors uint)
                           (description (string-ascii 300)))
    (let ((tour-id (+ (var-get tour-counter) u1)))
        (map-set tours
            { tour-id: tour-id }
            {
                garden-id: garden-id,
                guide: tx-sender,
                tour-date: tour-date,
                max-visitors: max-visitors,
                current-visitors: u0,
                description: description,
                active: true
            }
        )
        (var-set tour-counter tour-id)
        (ok tour-id)
    )
)

(define-public (book-tour (tour-id uint))
    (let ((tour-data (unwrap! (map-get? tours { tour-id: tour-id }) ERR-TOUR-NOT-FOUND)))
        (asserts! (get active tour-data) ERR-TOUR-NOT-FOUND)
        (asserts! (< (get current-visitors tour-data) (get max-visitors tour-data)) ERR-TOUR-FULL)
        (map-set tour-bookings
            { tour-id: tour-id, visitor: tx-sender }
            { booked-at: stacks-block-height }
        )
        (map-set tours
            { tour-id: tour-id }
            (merge tour-data { current-visitors: (+ (get current-visitors tour-data) u1) })
        )
        (ok true)
    )
)

(define-read-only (get-tour (tour-id uint))
    (map-get? tours { tour-id: tour-id })
)

(define-read-only (is-booked (tour-id uint) (visitor principal))
    (is-some (map-get? tour-bookings { tour-id: tour-id, visitor: visitor }))
)
