# 🃏 Bisca - Jogo de Cartas Multiplayer

Uma implementação digital do clássico jogo de cartas "Bisca", desenvolvida utilizando a **Godot Engine**. Este projeto foca em trazer a experiência da mesa de jogo para o ambiente virtual, contando com suporte a partidas multiplayer (arquitetura Cliente/Servidor), gerenciamento de cartas e animações dinâmicas.

## ⚙️ Funcionalidades Principais

* **Multiplayer / Networking:** Arquitetura de rede implementada via GDScript (`NetworkManager.gd` e `Server.gd`), permitindo conexão entre jogadores para partidas online/LAN.
* **Sistema de Animação:** Gerenciamento de movimentos fluídos de compra, descarte e distribuição de cartas através do `AnimationManager.gd`.
* **Lógica de Jogo:** Estruturas de dados, valores das cartas e comportamentos implementados em `CardData.gd` e `carta.gd`.
* **Interface de Usuário (UI):** Visão dedicada do jogador (`PlayerView.tscn` e `PlayerView.gd`) com controle de mão e exibição da mesa (`MesaDeJogo.tscn`).
* **Deck Completo:** Assets visuais para todos os naipes e coringas estruturados em `/assets/images/cards/`.

## 🛠️ Tecnologias Utilizadas

* **Motor Gráfico:** [Godot Engine](https://godotengine.org/)
* **Linguagem:** GDScript
* **Arquitetura:** Orientação a Objetos e Nodes (Cenas independentes e instanciáveis)

## 📂 Estrutura do Projeto

* `assets/images/`: Sprites das cartas (`/cards`) e elementos de interface (`/ui`).
* `scenes/`: Cenas da Godot divididas entre a lógica visual de jogo (`/gameplay`) e interface do usuário (`/ui`).
* `scripts/`: Toda a lógica em GDScript.
  * `/gameplay/`: Regras e comportamentos atrelados diretamente às cartas (`carta.gd`).
  * `/systems/`: Sistemas centrais do jogo (`NetworkManager.gd`, `Server.gd`, `CardData.gd` e `AnimationManager.gd`).
  * `/ui/`: Controle de interface e interações do jogador (`PlayerView.gd`).

## 🚀 Como Executar o Projeto Localmente

1. Certifique-se de ter a Godot Engine instalada em sua máquina.
2. Clone o repositório utilizando o comando: `git clone https://github.com/HeitorQuartezani/bisca.git`
3. Abra a Godot Engine, clique em "Importar" e navegue até a pasta clonada.
4. Selecione o arquivo `project.godot`.
5. Pressione F5 (ou clique no botão de Play no canto superior direito do editor) para iniciar a cena principal.

## 👨‍💻 Autor

**Heitor C. Quartezani**
Estatístico e Cientista de Dados | Mestrando em Ciência da Computação (PPGI-UFES)
