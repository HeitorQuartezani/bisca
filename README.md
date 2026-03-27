# 🃏 Bisca Multiplayer em Godot (Laboratório)

Uma tentativa de digitalizar o clássico jogo de cartas "Bisca" usando a **Godot Engine** e GDScript, com o desafio extra de montar um sistema multiplayer (cliente/servidor).

⚠️ **Aviso de Estado do Projeto:** Sendo 100% sincero, isso aqui é um laboratório de testes. O código tem aquele "código espaguete" clássico, lógicas que poderiam ser melhores e, com certeza, alguns bugs. A ideia principal era aprender a arquitetura de rede da Godot, então não espere um jogo polido ou finalizado.

## 🛠️ O que tem no repositório

* **Lógica de Jogo:** Regras, trunfo e comportamentos das cartas (arquivos como `CardData.gd` e `carta.gd`).
* **Rede "Na Raça":** Scripts dedicados a tentar fazer as instâncias se conectarem (`NetworkManager.gd` e `Server.gd`).
* **Interface e Animação:** Cenas da mesa (`MesaDeJogo.tscn`), visão do jogador e um gerenciador básico para animar a compra e descarte de cartas.

## 🚀 Quer testar? (Por sua conta e risco)

1. Tenha a Godot Engine instalada na sua máquina.
2. Clone o repositório e importe o arquivo `project.godot` na engine.
3. Dê Play (F5) e descubra o que acontece!

## 👨‍💻 Autor
**Heitor C. Quartezani**
