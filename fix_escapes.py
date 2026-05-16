with open(r'd:\Projects\kanakku_flutter\lib\features\dashboard\presentation\dashboard_screen.dart', 'r', encoding='utf-8') as f:
    text = f.read()

text = text.replace(r'\?', '?')

with open(r'd:\Projects\kanakku_flutter\lib\features\dashboard\presentation\dashboard_screen.dart', 'w', encoding='utf-8') as f:
    f.write(text)
