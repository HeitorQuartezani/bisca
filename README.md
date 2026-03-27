# 🃏 Bisca Multiplayer em Godot (Projeto Inacabado / Laboratório)

Uma tentativa de digitalizar o clássico jogo de cartas "Bisca" utilizando a **Godot Engine** e GDScript, com o desafio extra de implementar um sistema multiplayer (cliente/servidor).

⚠️ **Aviso de Estado do Projeto:** Sendo 100% sincero, este projeto é mais uma experiência de aprendizagem e um laboratório de testes do que um jogo polido. O objetivo principal foi tentar dominar a arquitetura de rede da Godot e a gestão de estado do jogo. O código tem a sua dose de "esparguete", lógicas que poderiam ser mais limpas e, muito provavelmente, bugs à mistura. Não esperes um produto finalizado ou livre de falhas!

## 🛠️ O que tem lá dentro (a arquitetura possível)

Apesar da confusão natural de um projeto em desenvolvimento, as fundações de um jogo de cartas online estão lá:

* **Lógica e Dados:** Estruturação das regras, valores do trunfo e comportamentos das cartas (em ficheiros como `CardData.gd` e `carta.gd`).
* **Multiplayer "Na Raça":** Scripts dedicados a tentar fazer as instâncias comunicarem entre si através de uma arquitetura rudimentar de rede (`NetworkManager.gd` e `Server.gd`).
* **Sistema de Animações:** Um gestor criado para tentar dar alguma fluidez visual na hora de puxar, descartar e mover as cartas pela mesa (`AnimationManager.gd`).
* **Interface (UI):** Cenas que gerem a visão da mesa e o controlo da mão do jogador (`PlayerView.tscn` e `MesaDeJogo.tscn`).

## 🚀 Como testar (por tua conta e risco)

Se tiveres curiosidade em ver o estado atual, tentar compilar ou apenas aproveitar algum pedaço de código:

1. Garante que tens a Godot Engine instalada na tua máquina.
2. Clona este repositório para o teu ambiente local.
3. Importa o projeto na Godot selecionando o ficheiro `project.godot`.
4. Prime F5 (ou clica no Play) e descobre o que acontece.

## 👨‍💻 Autor
**Heitor C. Quartezani**
