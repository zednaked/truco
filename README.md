# Truco Online

Um jogo de Truco multiplayer desenvolvido com Flutter Web e Node.js.

## 🎮 Jogar Agora

O jogo está disponível online em:
- **Cliente Web**: https://zednaked.github.io/truco/
- **Servidor**: https://truco-lrgy.onrender.com

## 🚀 Tecnologias

- **Frontend**: Flutter Web
  - socket_io_client para comunicação em tempo real
  - provider para gerenciamento de estado
  - flutter_animate para animações
  - Efeitos 3D nas cartas usando Matrix4

- **Backend**: Node.js
  - Express para servidor web
  - Socket.IO para comunicação em tempo real
  - CORS habilitado para produção

## 🎯 Funcionalidades

- Jogo multiplayer em tempo real
- Interface responsiva e moderna
- Animações fluidas
- Efeito 3D nas cartas
- Sistema de pontuação
- Botão de Truco com animação
- Visualização das cartas da rodada anterior

## 🔧 Desenvolvimento Local

### Cliente (Flutter)

```bash
cd truco_client
flutter pub get
flutter run -d chrome
```

### Servidor (Node.js)

```bash
cd truco_server
npm install
npm start
```

## 📦 Deploy

### Cliente (GitHub Pages)
O cliente está hospedado no GitHub Pages. Para fazer um novo deploy:

```bash
cd truco_client
flutter build web --base-href /truco/
# Copiar conteúdo da pasta build/web para a pasta docs
git add .
git commit -m "Update web build"
git push origin gh-pages
```

### Servidor (Render)
O servidor está hospedado no Render.com com deploy automático da branch main.
- URL do servidor: https://truco-lrgy.onrender.com
- Healthcheck endpoint: GET https://truco-lrgy.onrender.com/

## 🔌 Endpoints

### WebSocket
O servidor utiliza Socket.IO para comunicação em tempo real:

```javascript
// Conexão em produção
io.connect('https://truco-lrgy.onrender.com')

// Conexão local
io.connect('http://localhost:3001')
```

### Eventos Socket.IO

- `joinGame`: Entrar em uma partida
- `gameStart`: Início do jogo
- `cardPlayed`: Carta jogada
- `changeTurn`: Mudança de turno
- `roundResult`: Resultado da rodada
- `trucoRequested`: Pedido de truco
- `trucoAccepted`: Truco aceito

## 👥 Contribuição

Sinta-se à vontade para contribuir com o projeto através de Pull Requests.

## 📝 Licença

Este projeto está sob a licença MIT.
