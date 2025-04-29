;; AssetVault - a secure digital asset management system
;; Constants for error codes
(define-constant ERR-ASSET-EXISTS u100)
(define-constant ERR-ASSET-NOT-FOUND u101)
(define-constant ERR-INVALID-ASSET u102)
(define-constant ERR-NOT-OWNER u103)

;; Define a map to store asset ownership information
(define-map asset-registry
  {asset-id: (buff 32)}  ;; Key: Asset identifier
  {owner: principal})    ;; Value: Asset owner principal

;; Define a map to track assets owned by each entity
(define-map owner-assets
  {entity: principal}
  {asset-count: uint})

;; Public function to store a new asset
(define-public (store-asset (asset-id (buff 32)))
  (let ((entity tx-sender))
    (if (<= (len asset-id) u32)
        (if (is-some (map-get? asset-registry {asset-id: asset-id}))
            (err ERR-ASSET-EXISTS)
            (begin
              (map-set asset-registry {asset-id: asset-id} {owner: entity})
              (map-set owner-assets {entity: entity} 
                {asset-count: (+ u1 (default-to u0 (get asset-count (map-get? owner-assets {entity: entity}))))})
              (ok true)))
        (err ERR-INVALID-ASSET))))

;; Public function to check if an asset is stored
(define-public (is-asset-stored (asset-id (buff 32)))
  (ok (is-some (map-get? asset-registry {asset-id: asset-id}))))

;; Public function to get the owner of a stored asset
(define-public (get-asset-owner (asset-id (buff 32)))
  (match (map-get? asset-registry {asset-id: asset-id})
    registration (ok (get owner registration))
    (err ERR-ASSET-NOT-FOUND)))

;; Public function to transfer asset ownership
(define-public (transfer-asset (asset-id (buff 32)) (new-owner principal))
  (let 
    (
      (entity tx-sender)
      (current-owner-assets (get asset-count (default-to {asset-count: u0} (map-get? owner-assets {entity: entity}))))
    )
    (if (and 
          (<= (len asset-id) u32) 
          (is-some (map-get? asset-registry {asset-id: asset-id}))
          (not (is-eq new-owner entity))
        )
        (match (map-get? asset-registry {asset-id: asset-id})
          registration 
            (if (is-eq (get owner registration) entity)
                (begin
                  (map-set asset-registry {asset-id: asset-id} {owner: new-owner})
                  (map-set owner-assets {entity: entity} 
                    {asset-count: (- current-owner-assets u1)})
                  (map-set owner-assets {entity: new-owner} 
                    {asset-count: (+ u1 (default-to u0 (get asset-count (map-get? owner-assets {entity: new-owner}))))})
                  (ok true))
                (err ERR-NOT-OWNER))
          (err ERR-ASSET-NOT-FOUND))
        (err ERR-INVALID-ASSET))))

;; Public function to remove an asset
(define-public (remove-asset (asset-id (buff 32)))
  (let ((entity tx-sender))
    (if (<= (len asset-id) u32)
        (match (map-get? asset-registry {asset-id: asset-id})
          registration 
            (if (is-eq (get owner registration) entity)
                (begin
                  (map-delete asset-registry {asset-id: asset-id})
                  (map-set owner-assets {entity: entity} 
                    {asset-count: (- (default-to u0 (get asset-count (map-get? owner-assets {entity: entity}))) u1)})
                  (ok true))
                (err ERR-NOT-OWNER))
          (err ERR-ASSET-NOT-FOUND))
        (err ERR-INVALID-ASSET))))

;; Public function to get the number of assets owned by an entity
(define-public (get-owner-asset-count (entity principal))
  (ok (default-to u0 (get asset-count (map-get? owner-assets {entity: entity})))))

;; Public function to check if an entity owns any assets
(define-public (owner-has-assets (entity principal))
  (ok (> (default-to u0 (get asset-count (map-get? owner-assets {entity: entity}))) u0)))