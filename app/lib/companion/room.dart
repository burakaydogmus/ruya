import 'package:ruya/l10n/app_localizations.dart';

part 'room_catalog.g.dart';

/// Fixed places in the companions' room. Every slot holds one item (or none),
/// so decorating is a choice per place, not free arrangement.
enum RoomSlot {
  window,
  wall,
  light,
  plant,
  rug,
  cushion;

  String label(AppLocalizations l10n) => switch (this) {
        RoomSlot.window => l10n.room_slotWindow,
        RoomSlot.wall => l10n.room_slotWall,
        RoomSlot.light => l10n.room_slotLight,
        RoomSlot.plant => l10n.room_slotPlant,
        RoomSlot.rug => l10n.room_slotRug,
        RoomSlot.cushion => l10n.room_slotCushion,
      };
}

/// One piece of furniture drawn by tool/pets/room.py.
class RoomItemArt {
  const RoomItemArt(this.id, this.slot, this.unlockDay, this.width, this.height);

  final String id;
  final RoomSlot slot;

  /// Days together after which the item arrives.
  final int unlockDay;

  /// Size in art pixels.
  final int width;
  final int height;

  String get asset => 'assets/room/$id.png';
}

List<RoomItemArt> roomItemsFor(RoomSlot slot) =>
    kRoomItems.values.where((i) => i.slot == slot).toList()..sort((a, b) => a.unlockDay.compareTo(b.unlockDay));

/// What a new room starts with.
const Map<RoomSlot, String> kDefaultRoom = {
  RoomSlot.window: 'win_wood',
  RoomSlot.light: 'lamp',
  RoomSlot.plant: 'plant',
  RoomSlot.cushion: 'cushion_pink',
};
