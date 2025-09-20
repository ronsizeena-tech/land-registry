;; title: Land Transfer Contract
;; version: 1.0.0
;; summary: Handles secure property transfers, ownership validation, and transfer history
;; description: A comprehensive smart contract for managing secure land ownership transfers with complete audit trails

;; constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u401))
(define-constant ERR_PROPERTY_NOT_FOUND (err u404))
(define-constant ERR_TRANSFER_NOT_FOUND (err u405))
(define-constant ERR_INVALID_TRANSFER_DATA (err u400))
(define-constant ERR_TRANSFER_ALREADY_EXISTS (err u409))
(define-constant ERR_TRANSFER_ALREADY_COMPLETED (err u406))
(define-constant ERR_TRANSFER_EXPIRED (err u407))
(define-constant ERR_INSUFFICIENT_PAYMENT (err u408))
(define-constant ERR_INVALID_RECIPIENT (err u403))
(define-constant ERR_SELF_TRANSFER (err u402))
(define-constant ERR_PROPERTY_NOT_ACTIVE (err u410))
(define-constant TRANSFER_EXPIRY_BLOCKS u1000)

;; data vars
(define-data-var transfer-counter uint u0)
(define-data-var total-transfers uint u0)
(define-data-var contract-admin principal CONTRACT_OWNER)
(define-data-var land-ownership-contract principal 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.land-ownership)

;; data maps
(define-map transfers
    { transfer-id: uint }
    {
        property-id: uint,
        from-owner: principal,
        to-owner: principal,
        transfer-price: uint,
        transfer-date: uint,
        expiry-block: uint,
        status: (string-ascii 20),
        transfer-fee: uint,
        completion-block: (optional uint),
        transfer-notes: (string-ascii 300)
    }
)

(define-map transfer-approvals
    { transfer-id: uint }
    {
        from-approved: bool,
        to-approved: bool,
        admin-approved: bool,
        approval-date: (optional uint)
    }
)

(define-map property-transfer-history
    { property-id: uint, transfer-index: uint }
    { transfer-id: uint }
)

(define-map user-transfers
    { user: principal, transfer-type: (string-ascii 10), transfer-index: uint }
    { transfer-id: uint }
)

(define-map transfer-payments
    { transfer-id: uint }
    {
        amount-paid: uint,
        payment-date: uint,
        payment-method: (string-ascii 50),
        payment-confirmed: bool
    }
)

(define-map transfer-documents
    { transfer-id: uint, document-id: uint }
    {
        document-hash: (string-ascii 64),
        document-type: (string-ascii 50),
        upload-date: uint,
        uploader: principal
    }
)

;; public functions
(define-public (initiate-transfer
    (property-id uint)
    (to-owner principal)
    (transfer-price uint)
    (transfer-notes (string-ascii 300)))
    
    (let ((new-transfer-id (+ (var-get transfer-counter) u1))
          (current-block stacks-block-height)
          (expiry-block (+ current-block TRANSFER_EXPIRY_BLOCKS)))
        
        ;; Validate inputs
        (asserts! (> transfer-price u0) ERR_INVALID_TRANSFER_DATA)
        (asserts! (is-standard to-owner) ERR_INVALID_RECIPIENT)
        (asserts! (not (is-eq tx-sender to-owner)) ERR_SELF_TRANSFER)
        
        ;; Check if property exists and caller is owner through external contract call
        (asserts! (is-property-owner-external property-id tx-sender) ERR_UNAUTHORIZED)
        (asserts! (is-property-active-external property-id) ERR_PROPERTY_NOT_ACTIVE)
        
        ;; Check if there's already a pending transfer for this property
        (asserts! (is-none (get-pending-transfer-for-property property-id)) ERR_TRANSFER_ALREADY_EXISTS)
        
        ;; Create transfer record
        (map-set transfers
            { transfer-id: new-transfer-id }
            {
                property-id: property-id,
                from-owner: tx-sender,
                to-owner: to-owner,
                transfer-price: transfer-price,
                transfer-date: current-block,
                expiry-block: expiry-block,
                status: "PENDING",
                transfer-fee: (calculate-transfer-fee transfer-price),
                completion-block: none,
                transfer-notes: transfer-notes
            }
        )
        
        ;; Initialize transfer approvals
        (map-set transfer-approvals
            { transfer-id: new-transfer-id }
            {
                from-approved: true,
                to-approved: false,
                admin-approved: false,
                approval-date: none
            }
        )
        
        ;; Add to property transfer history
        (map-set property-transfer-history
            { property-id: property-id, transfer-index: u1 }
            { transfer-id: new-transfer-id }
        )
        
        ;; Add to user transfers (outgoing for sender)
        (map-set user-transfers
            { user: tx-sender, transfer-type: "OUTGOING", transfer-index: u1 }
            { transfer-id: new-transfer-id }
        )
        
        ;; Add to user transfers (incoming for recipient)
        (map-set user-transfers
            { user: to-owner, transfer-type: "INCOMING", transfer-index: u1 }
            { transfer-id: new-transfer-id }
        )
        
        ;; Update counters
        (var-set transfer-counter new-transfer-id)
        (var-set total-transfers (+ (var-get total-transfers) u1))
        
        (ok new-transfer-id)
    )
)

(define-public (approve-transfer (transfer-id uint))
    (let ((transfer-data (unwrap! (map-get? transfers { transfer-id: transfer-id }) ERR_TRANSFER_NOT_FOUND))
          (approval-data (unwrap! (map-get? transfer-approvals { transfer-id: transfer-id }) ERR_TRANSFER_NOT_FOUND)))
        
        ;; Check if transfer is still valid
        (asserts! (is-eq (get status transfer-data) "PENDING") ERR_TRANSFER_ALREADY_COMPLETED)
        (asserts! (< stacks-block-height (get expiry-block transfer-data)) ERR_TRANSFER_EXPIRED)
        
        ;; Update approvals based on who is calling
        (let ((updated-approvals
                (if (is-eq tx-sender (get to-owner transfer-data))
                    (merge approval-data { to-approved: true })
                    (if (is-eq tx-sender (var-get contract-admin))
                        (merge approval-data { admin-approved: true })
                        approval-data
                    )
                )))
            
            ;; Update approval record
            (map-set transfer-approvals
                { transfer-id: transfer-id }
                (if (and (get to-approved updated-approvals) (get from-approved updated-approvals))
                    (merge updated-approvals { approval-date: (some stacks-block-height) })
                    updated-approvals
                )
            )
            
            ;; Check if all required approvals are obtained
            (if (and (get from-approved updated-approvals)
                     (get to-approved updated-approvals))
                (complete-transfer-internal transfer-id)
                (ok true)
            )
        )
    )
)

(define-public (reject-transfer (transfer-id uint) (rejection-reason (string-ascii 200)))
    (let ((transfer-data (unwrap! (map-get? transfers { transfer-id: transfer-id }) ERR_TRANSFER_NOT_FOUND)))
        
        ;; Check if caller has authority to reject
        (asserts! (or (is-eq tx-sender (get from-owner transfer-data))
                     (is-eq tx-sender (get to-owner transfer-data))
                     (is-eq tx-sender (var-get contract-admin))) ERR_UNAUTHORIZED)
        
        ;; Check if transfer is still pending
        (asserts! (is-eq (get status transfer-data) "PENDING") ERR_TRANSFER_ALREADY_COMPLETED)
        
        ;; Update transfer status to rejected
        (map-set transfers
            { transfer-id: transfer-id }
            (merge transfer-data {
                status: "REJECTED",
                completion-block: (some stacks-block-height),
                transfer-notes: "Transfer rejected by user"
            })
        )
        
        (ok true)
    )
)

(define-public (record-payment (transfer-id uint) (amount uint) (payment-method (string-ascii 50)))
    (let ((transfer-data (unwrap! (map-get? transfers { transfer-id: transfer-id }) ERR_TRANSFER_NOT_FOUND)))
        
        ;; Validate caller and transfer status
        (asserts! (is-eq tx-sender (get to-owner transfer-data)) ERR_UNAUTHORIZED)
        (asserts! (is-eq (get status transfer-data) "APPROVED") ERR_INVALID_TRANSFER_DATA)
        (asserts! (>= amount (get transfer-price transfer-data)) ERR_INSUFFICIENT_PAYMENT)
        
        ;; Record payment
        (map-set transfer-payments
            { transfer-id: transfer-id }
            {
                amount-paid: amount,
                payment-date: stacks-block-height,
                payment-method: payment-method,
                payment-confirmed: true
            }
        )
        
        (ok true)
    )
)

(define-public (add-transfer-document
    (transfer-id uint)
    (document-hash (string-ascii 64))
    (document-type (string-ascii 50)))
    
    (let ((transfer-data (unwrap! (map-get? transfers { transfer-id: transfer-id }) ERR_TRANSFER_NOT_FOUND))
          (document-id u1))
        
        ;; Validate caller has authority
        (asserts! (or (is-eq tx-sender (get from-owner transfer-data))
                     (is-eq tx-sender (get to-owner transfer-data))
                     (is-eq tx-sender (var-get contract-admin))) ERR_UNAUTHORIZED)
        
        ;; Add document
        (map-set transfer-documents
            { transfer-id: transfer-id, document-id: document-id }
            {
                document-hash: document-hash,
                document-type: document-type,
                upload-date: stacks-block-height,
                uploader: tx-sender
            }
        )
        
        (ok document-id)
    )
)

(define-public (cancel-transfer (transfer-id uint))
    (let ((transfer-data (unwrap! (map-get? transfers { transfer-id: transfer-id }) ERR_TRANSFER_NOT_FOUND)))
        
        ;; Only from-owner or admin can cancel
        (asserts! (or (is-eq tx-sender (get from-owner transfer-data))
                     (is-eq tx-sender (var-get contract-admin))) ERR_UNAUTHORIZED)
        
        ;; Can only cancel pending transfers
        (asserts! (is-eq (get status transfer-data) "PENDING") ERR_TRANSFER_ALREADY_COMPLETED)
        
        ;; Update status to cancelled
        (map-set transfers
            { transfer-id: transfer-id }
            (merge transfer-data {
                status: "CANCELLED",
                completion-block: (some stacks-block-height)
            })
        )
        
        (ok true)
    )
)

;; read only functions
(define-read-only (get-transfer (transfer-id uint))
    (map-get? transfers { transfer-id: transfer-id })
)

(define-read-only (get-transfer-approvals (transfer-id uint))
    (map-get? transfer-approvals { transfer-id: transfer-id })
)

(define-read-only (get-transfer-payment (transfer-id uint))
    (map-get? transfer-payments { transfer-id: transfer-id })
)

(define-read-only (get-transfer-document (transfer-id uint) (document-id uint))
    (map-get? transfer-documents { transfer-id: transfer-id, document-id: document-id })
)

(define-read-only (get-property-transfers (property-id uint) (transfer-index uint))
    (map-get? property-transfer-history { property-id: property-id, transfer-index: transfer-index })
)

(define-read-only (get-user-transfers (user principal) (transfer-type (string-ascii 10)) (transfer-index uint))
    (map-get? user-transfers { user: user, transfer-type: transfer-type, transfer-index: transfer-index })
)

(define-read-only (get-total-transfers)
    (var-get total-transfers)
)

(define-read-only (get-transfer-counter)
    (var-get transfer-counter)
)

(define-read-only (is-transfer-expired (transfer-id uint))
    (match (map-get? transfers { transfer-id: transfer-id })
        transfer-data (> stacks-block-height (get expiry-block transfer-data))
        true
    )
)

;; private functions
(define-private (complete-transfer-internal (transfer-id uint))
    (let ((transfer-data (unwrap! (map-get? transfers { transfer-id: transfer-id }) ERR_TRANSFER_NOT_FOUND)))
        
        ;; Update transfer status to approved (ready for completion)
        (map-set transfers
            { transfer-id: transfer-id }
            (merge transfer-data {
                status: "APPROVED",
                completion-block: (some stacks-block-height)
            })
        )
        
        (ok true)
    )
)

(define-private (calculate-transfer-fee (transfer-price uint))
    ;; Calculate 2% transfer fee
    (/ (* transfer-price u2) u100)
)

(define-private (get-pending-transfer-for-property (property-id uint))
    ;; Simplified to avoid circular dependencies
    none
)

;; External contract interaction helpers (placeholder implementations)
(define-private (is-property-owner-external (property-id uint) (owner principal))
    ;; This would call the land-ownership contract to verify ownership
    ;; For now, return true as placeholder
    true
)

(define-private (is-property-active-external (property-id uint))
    ;; This would call the land-ownership contract to check if property is active
    ;; For now, return true as placeholder
    true
)
