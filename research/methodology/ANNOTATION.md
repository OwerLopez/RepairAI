# Handheld garment study protocol

## Acquisition

Recruit consenting contributors after the authors resolve local ethics requirements and approve the participant materials. Acquire unworn garments against varied home backgrounds with mobile devices. For each physical item, collect a full view and close views with ordinary, low and directional lighting when capture permits. Include undamaged garments, decorative holes, prints, folds, seams, occlusion and objects outside the textile domain. Store a pseudonymous garment ID with session, camera family and general capture conditions. Keep the consent register separate from imagery and metadata.

Use independent purposes for internal analysis, redistribution and user research. Remove EXIF and reject photos containing identifying people, documents or labels with personal information. Document withdrawal and retention windows before collection. Production captures stay in the device journal and remain outside all research manifests.

## Annotation and review

- Hole means loss of material with an opening through the fabric. A seam gap lies along the original stitched junction with fabric edges substantially intact. Tear denotes a discontinuity within material where adjacent fabric edges remain visible. Include other and indeterminate labels for out-of-scope and ambiguous views.
- Annotate each visible defect independently. Trace tight polygons around visible damage, record enclosing boxes, and mark boundaries hidden by a fold or obstruction as partially visible. A whole view without visibility sufficient to decide receives an indeterminate label. Deliberate distressing receives a separate provenance flag.
- Record fabric family using the garment label or in-person confirmation. Record unknown when the label is absent. Capture physical dimensions only when measured with a ruler.
- Two annotators independently review the same stratified audit subset and each disputed sample. Use class agreement and overlap on matched regions, report percent agreement plus Cohen's kappa where estimable, and have a textile reviewer adjudicate disagreements.

## Evaluation before publication

Split by physical garment and by linked capture identity before any augmentation. Reserve a hardware and background stratum as an external holdout. Freeze data revision, split, operating threshold and analysis code before opening that holdout. Measure per-class detection AP and average recall, F1 at a locked operating point, localization at IoU 0.50 and 0.50:0.95, and image-level false alarms on verified negatives. Use mask IoU and Dice only with valid masks. Assess calibration and risk–coverage when both correct and incorrect predictions are represented. Bootstrap by garment and report uncertainty for all primary endpoints.

For procedure compatibility, ask independent textile reviewers to judge anonymized candidate plans per case, with the same observations and tools shown to every system. Compare expert-scored compatibility and unsafe recommendation rates for metadata ranking and an expanded grounded retriever. Assess agreement before adjudication. Measure usability and repair completion with participants under a separate approved study. Have reviewers compare the before and after photos and record what cannot be determined visually. Record latency, peak RAM, device model, OS and network state. A photo can document visible change while the user or reviewer reports repair completion.
