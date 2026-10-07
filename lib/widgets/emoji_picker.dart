import 'package:bumble/constants/app_colors.dart';
import 'package:flutter/material.dart';

class _EmojiCategory {
  final String icon;
  final String label;
  final List<String> emojis;

  const _EmojiCategory(this.icon, this.label, this.emojis);
}

List<String> _split(String raw) => raw.split(' ');

final List<_EmojiCategory> _categories = [
  _EmojiCategory(
    '😀',
    'Ekspresi',
    _split(
      '😀 😃 😄 😁 😆 😅 😂 🤣 😊 😇 🙂 🙃 😉 😌 😍 🥰 😘 😗 😙 😚 😋 😛 😝 😜 '
      '🤪 🤨 🧐 🤓 😎 🤩 🥳 😏 😒 😞 😔 😟 😕 🙁 😣 😖 😫 😩 🥺 😢 😭 😤 😠 😡 '
      '🤬 🤯 😳 🥵 🥶 😱 😨 😰 😥 😓 🤗 🤔 🤭 🤫 🤥 😶 😐 😑 😬 🙄 😯 😦 😧 😮 '
      '😲 🥱 😴 🤤 😪 😵 🤐 🥴 🤢 🤮 🤧 😷 🤒 🤕 🤑 🤠 😈 👿 🤡 💩 👻 💀 👽 🤖 '
      '🙈 🙉 🙊',
    ),
  ),
  _EmojiCategory(
    '👍',
    'Tangan & orang',
    _split(
      '👍 👎 👌 ✌️ 🤞 🤟 🤘 🤙 👈 👉 👆 👇 ☝️ ✋ 🤚 🖖 👋 🤏 💪 🙏 👏 🙌 👐 🤲 '
      '🤝 ✍️ 💅 🤳 👀 👅 👄 🙋 🙆 🙅 🤦 🤷 💃 🕺',
    ),
  ),
  _EmojiCategory(
    '❤️',
    'Hati & simbol',
    _split(
      '❤️ 🧡 💛 💚 💙 💜 🖤 🤍 🤎 💔 ❣️ 💕 💞 💓 💗 💖 💘 💝 💟 💋 💯 💢 💥 💫 '
      '💦 💨 ✨ ⭐ 🌟 🔥 🎉 🎊 🎁 🎈',
    ),
  ),
  _EmojiCategory(
    '🐶',
    'Hewan & alam',
    _split(
      '🐶 🐱 🐭 🐹 🐰 🦊 🐻 🐼 🐨 🐯 🦁 🐮 🐷 🐸 🐵 🐔 🐧 🐦 🐤 🦆 🦉 🦋 🐛 🐝 '
      '🐞 🐢 🐍 🐙 🐬 🐳 🐟 🌸 🌹 🌻 🌼 🌷 🌱 🌴 🌵 🍀 🍁 🌈 ☀️ 🌙 ❄️ ⚡',
    ),
  ),
  _EmojiCategory(
    '🍔',
    'Makanan & minuman',
    _split(
      '🍎 🍊 🍋 🍌 🍉 🍇 🍓 🍒 🍑 🥭 🍍 🥥 🥑 🍅 🌽 🥕 🍞 🥐 🧀 🍳 🥞 🍔 🍟 🍕 '
      '🌭 🌮 🍜 🍣 🍦 🍩 🍪 🎂 🍰 🍫 🍬 ☕ 🍵 🍺 🍷 🥂 🍹 🥤',
    ),
  ),
  _EmojiCategory(
    '⚽',
    'Aktivitas',
    _split(
      '⚽ 🏀 🏈 ⚾ 🎾 🏐 🎱 🏓 🏸 🥊 🎯 🎮 🎲 🎳 🎵 🎶 🎤 🎧 🎸 🎹 🎬 📷 🏆 🥇 '
      '🏊 🚴',
    ),
  ),
  _EmojiCategory(
    '✈️',
    'Perjalanan & benda',
    _split(
      '🚗 🚕 🚌 🏍️ 🚲 ✈️ 🚀 🏠 🏖️ ⛰️ 🌍 📱 💻 📸 💡 📚 ✏️ 💼 🔑 💍 👑 👗 👟 '
      '👓 🕶️ 🎒 ☂️ ⏰',
    ),
  ),
];

class EmojiPickerPanel extends StatefulWidget {
  final ValueChanged<String> onEmojiSelected;
  final VoidCallback onBackspace;
  final double height;

  const EmojiPickerPanel({
    super.key,
    required this.onEmojiSelected,
    required this.onBackspace,
    this.height = 260,
  });

  @override
  State<EmojiPickerPanel> createState() => _EmojiPickerPanelState();
}

class _EmojiPickerPanelState extends State<EmojiPickerPanel> {
  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    final emojis = _categories[_selected].emojis;

    return Container(
      height: widget.height,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.borderSoft)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: GridView.builder(
                key: ValueKey(_selected),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 8,
                ),
                itemCount: emojis.length,
                itemBuilder: (context, index) {
                  final emoji = emojis[index];
                  return InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => widget.onEmojiSelected(emoji),
                    child: Center(
                      child: Text(emoji, style: const TextStyle(fontSize: 26)),
                    ),
                  );
                },
              ),
            ),
            SizedBox(
              height: 44,
              child: Row(
                children: [
                  for (var i = 0; i < _categories.length; i++)
                    Expanded(
                      child: Semantics(
                        button: true,
                        selected: i == _selected,
                        label: _categories[i].label,
                        child: InkWell(
                          onTap: () => setState(() => _selected = i),
                          child: Container(
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  width: 2,
                                  color: i == _selected
                                      ? AppColors.primary
                                      : Colors.transparent,
                                ),
                              ),
                            ),
                            child: Text(
                              _categories[i].icon,
                              style: const TextStyle(fontSize: 20),
                            ),
                          ),
                        ),
                      ),
                    ),
                  Expanded(
                    child: IconButton(
                      tooltip: 'Hapus',
                      icon: const Icon(
                        Icons.backspace_outlined,
                        size: 20,
                        color: AppColors.textSecondary,
                      ),
                      onPressed: widget.onBackspace,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}