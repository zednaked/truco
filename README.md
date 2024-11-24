# Truco Multiplayer

Um jogo de Truco multiplayer em tempo real desenvolvido com Flutter (web) e Node.js.

## Tecnologias Utilizadas

- **Frontend**: Flutter Web
- **Backend**: Node.js com Socket.IO
- **Comunicação**: WebSocket
- **Dependências**:
  - Flutter:
    - socket_io_client
    - provider
    - flutter_animate
    - animated_text_kit
  - Node.js:
    - express
    - socket.io

## Estrutura do Projeto

```
truco-nov/
├── truco_client/       # Cliente Flutter
│   ├── lib/
│   │   ├── main.dart   # Lógica principal e UI
│   │   └── theme.dart  # Configurações de tema
│   └── pubspec.yaml    # Dependências Flutter
└── truco_server/       # Servidor Node.js
    └── server.js       # Lógica do servidor e WebSocket
```

## Funcionalidades

- Conexão em tempo real entre jogadores
- Sistema de salas para partidas
- Distribuição automática de cartas
- Sistema de turnos
- Controle de rodadas e pontuação
- Interface responsiva e animada
- Feedback visual do estado do jogo

## Como Executar

### Servidor (Node.js)

1. Navegue até a pasta do servidor:
```bash
cd truco_server
```

2. Instale as dependências:
```bash
npm install
```

3. Inicie o servidor:
```bash
node server.js
```

O servidor estará rodando em `http://localhost:3001`

### Cliente (Flutter Web)

1. Navegue até a pasta do cliente:
```bash
cd truco_client
```

2. Instale as dependências:
```bash
flutter pub get
```

3. Execute o cliente:
```bash
flutter run -d chrome
```

## Estado do Jogo

### Servidor
- Gerenciamento de salas
- Controle de turnos
- Distribuição de cartas
- Cálculo de pontuação
- Validação de jogadas

### Cliente
- Gestão de estado com Provider
- Animações fluidas
- Feedback visual de ações
- Tratamento de erros
- Reconexão automática

## Fluxo do Jogo

1. Jogador conecta ao servidor
2. Aguarda segundo jogador
3. Início da partida com distribuição de cartas
4. Alternância de turnos para jogadas
5. Cálculo de vencedor da rodada
6. Atualização de pontuação
7. Nova rodada ou fim do jogo

## Eventos Socket.IO

### Cliente → Servidor
- `joinGame`: Solicita entrada em uma sala
- `playCard`: Envia carta jogada

### Servidor → Cliente
- `gameStart`: Inicia jogo com dados iniciais
- `changeTurn`: Alterna turno entre jogadores
- `cardPlayed`: Notifica jogada realizada
- `roundResult`: Resultado da rodada
- `handComplete`: Resultado da mão

## Próximos Passos

- [ ] Implementar regras avançadas do Truco
- [ ] Adicionar efeitos sonoros
- [ ] Melhorar tratamento de erros
- [ ] Sistema de autenticação
- [ ] Salas persistentes
- [ ] Modo espectador
- [ ] Ranking de jogadores
