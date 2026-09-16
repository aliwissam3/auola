/// Whether an item tagged with [itemPharmacyId] should be visible to
/// someone whose own pharmacy is [currentPharmacyId].
///
/// Both nulls are treated as "show it" rather than "hide it" — an
/// untagged item (created before multi-pharmacy assignment existed) or
/// an employee with no pharmacy set yet should never silently vanish
/// from view. Once both sides are actually set, only a match counts.
bool matchesPharmacy(String? itemPharmacyId, String? currentPharmacyId) {
  if (itemPharmacyId == null || currentPharmacyId == null) return true;
  return itemPharmacyId == currentPharmacyId;
}
