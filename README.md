# forge Backpack

Sistema de mochilas para FiveM (QBCore / Qbox) integrado ao **pr_bridge**.

O inventário usa **modelos de item** (`backpack`, `large_backpack`, etc.). Cada variação (médica, policial, 10kg, 15kg…) é um **perfil** salvo no JSON e identificado pela **metadata** `profile` do item.

---

## Resumo rápido

| Conceito | O que é |
|----------|---------|
| **Modelo de item** | Nome do item no ox/qb-inventory (`backpack`, `medical_backpack`…) |
| **Perfil** | Configuração lógica: slots, peso, jobs, senha, loja |
| **Metadata** | `profile` + `stash` + `label` no item do jogador |

Você pode ter **quantos perfis quiser** com poucos itens no inventário. Novos modelos são criados no admin e cadastrados no inventário (o script imprime o código no **F8**).

---

## Metadata do item

```json
{
  "profile": "small_civilian",
  "stash": "backpack_482913",
  "label": "Small Backpack"
}
```

| Campo | Função |
|-------|--------|
| `profile` | ID do perfil em `data/backpacks.json` → slots, peso, jobs, senha |
| `stash` | Criado na primeira abertura → stash privado único |
| `label` | Nome exibido no inventário (ox) |

- **Visual** = `itemModel` do perfil → modelo em `itemModels` no JSON
- **Comportamento** = dados do perfil (slots, peso, senha, jobs…)

---

## Fluxo do jogador

1. **Obter** — loja NPC, `/testemochila` (admin) ou give com metadata
2. **Visual** — baseado no modelo do perfil
3. **Abrir** — usar o item → animação → stash (`metadata.stash`)
4. **Senha / jobs** — definidos no perfil, não no item

---

## Perfis padrão (`data/backpacks.json`)

| Perfil | Label | Modelo | Loja | Slots | Peso | Senha | Restrição |
|--------|-------|--------|------|-------|------|-------|-----------|
| `small_civilian` | Small Backpack | `backpack` | Sim | 30 | 100000 | — | Todos |
| `large_secured` | Large Backpack | `large_backpack` | Sim | 50 | 500000 | `abcd` | Todos |
| `evidence_police` | Evidence Backpack | `evidence_backpack` | Não | 30 | 200000 | — | Só `police` |

---

## Instalação

### 1. Dependências

```
ox_lib
pr_bridge
qbx_core / qb-core
ox_inventory OU qb-inventory
ox_target OU qb-target
```

### 2. server.cfg

```cfg
ensure ox_lib
ensure pr_bridge
ensure qbx_core
ensure ox_inventory
ensure ox_target
ensure forge-backpack

setr pr_bridge:locale pt-br

add_ace group.admin forge-backpack.admin allow
add_ace group.admin command.backpackadmin allow
add_ace group.admin command.testemochila allow
```

### 3. Itens no inventário

Cadastre os **modelos de item** que o script usa. Na instalação vêm 3 padrão:

- `backpack`
- `large_backpack`
- `evidence_backpack`

O script registra o **usar item** automaticamente. **Não** use `client.event` no ox_inventory.

Arquivos de referência: `install/ox-items.txt` e `install/qb-items.txt`.

---

## Admin — `/backpackadmin`

### Gerenciar perfis

1. **Criar perfil** → escolhe o **modelo com foto** no menu
2. Formulário já vem **pré-preenchido** (copia de perfil existente do mesmo modelo ou defaults)
3. Salva em `data/backpacks.json` → `profiles`

### Modelos de item

1. Lista todos os modelos com **imagem** (inventário ou `image` no JSON)
2. **Criar novo modelo** → nome do item + label + imagem opcional
3. Ao **salvar/criar**, o console **F8** imprime o bloco pronto para copiar no ox/qb
4. **Editar** props, roupa, animação, preview
5. **Excluir** — só se nenhum perfil usar o modelo

> **Importante:** ao criar modelo novo no admin, cadastre o **mesmo nome** no inventário usando o texto do F8.

---

## Comando de teste — `/testemochila`

Entrega uma mochila para o admin com metadata aplicada.

```
/testemochila backpack small_civilian
/testemochila large_backpack large_secured
/testemochila backpack
```

| Argumento | Obrigatório | Descrição |
|-----------|-------------|-----------|
| `item_model` | Sim | Nome do modelo (`backpack`, `large_backpack`…) |
| `profile` | Não | ID do perfil (`small_civilian`). Sem isso, usa `Config.DefaultProfileByModel` |

Requer ACE `forge-backpack.admin`.

---

## Exemplo: ox_inventory

`ox_inventory/data/items.lua`:

```lua
['backpack'] = {
    label = 'Small Backpack',
    weight = 1000,
    stack = false,
    close = true,
    description = 'Mochila pequena com stash privado',
    consume = 0,
    buttons = {
        {
            label = 'Alterar Senha',
            action = function(slot)
                TriggerEvent('forge-backpack:client:changePasswordFromMenu', slot)
            end
        }
    }
},
['large_backpack'] = {
    label = 'Large Backpack',
    weight = 1500,
    stack = false,
    close = true,
    description = 'Mochila grande com senha',
    consume = 0,
    buttons = {
        {
            label = 'Alterar Senha',
            action = function(slot)
                TriggerEvent('forge-backpack:client:changePasswordFromMenu', slot)
            end
        }
    }
},
['evidence_backpack'] = {
    label = 'Evidence Backpack',
    weight = 1500,
    stack = false,
    close = true,
    description = 'Mochila de evidencias (policia)',
    consume = 0,
    buttons = {
        {
            label = 'Alterar Senha',
            action = function(slot)
                TriggerEvent('forge-backpack:client:changePasswordFromMenu', slot)
            end
        }
    }
},
```

**Testar:**

```
/testemochila backpack small_civilian
/giveitem [id] backpack 1 {"profile":"large_secured","label":"Large Backpack"}
```

**Imagens:** `ox_inventory/web/images/backpack.png` (ou nome em `image` do modelo no JSON).

---

## Exemplo: qb-inventory

`qb-core/shared/items.lua`:

```lua
['backpack'] = {
    name = 'backpack',
    label = 'Small Backpack',
    type = 'item',
    weight = 1000,
    unique = true,
    useable = true,
    shouldClose = true,
    description = 'Mochila pequena com stash privado',
},
['large_backpack'] = {
    name = 'large_backpack',
    label = 'Large Backpack',
    image = 'large_backpack.png',
    type = 'item',
    weight = 1500,
    unique = true,
    useable = true,
    shouldClose = true,
    description = 'Mochila grande com senha',
},
['evidence_backpack'] = {
    name = 'evidence_backpack',
    label = 'Evidence Backpack',
    image = 'evidence_backpack.png',
    type = 'item',
    weight = 1500,
    unique = true,
    useable = true,
    shouldClose = true,
    description = 'Mochila de evidencias (policia)',
},
```

**Testar:**

```
/testemochila backpack
```

> `useable = true` e `unique = true` são **obrigatórios** no qb.

---

## Criar mochila médica 15kg (exemplo)

1. `/backpackadmin` → **Gerenciar perfis** → **Criar**
2. Escolher modelo `backpack` (com foto)
3. ID: `medical_15kg` | Slots: `40` | Peso: `150000`
4. Salvar — **sem criar item novo** se usar modelo `backpack` existente

Se precisar de **item visual diferente** no inventário:

1. **Modelos de item** → **Criar** → ex: `medical_backpack`
2. Abrir **F8** e copiar o snippet para o inventário
3. Criar perfil usando `medical_backpack` como modelo

---

## Estrutura do JSON

```json
{
  "itemModels": {
    "backpack": {
      "label": "Small Backpack Model",
      "image": "backpack.png",
      "props": { ... },
      "clothing": { ... },
      "anim": { ... }
    }
  },
  "profiles": {
    "small_civilian": {
      "label": "Small Backpack",
      "itemModel": "backpack",
      "slots": 30,
      "weight": 100000,
      "shopEnabled": true
    }
  }
}
```

---

## Configuração (`shared/config.lua`)

```lua
Config.BackpackStyle = "clothing"  -- "clothing" ou "prop"

Config.AdminCommand = "backpackadmin"
Config.AdminAce = "forge-backpack.admin"
Config.TestCommand = "testemochila"

Config.DefaultProfileByModel = {
    backpack = "small_civilian",
    large_backpack = "large_secured",
    evidence_backpack = "evidence_police",
}
```

**Fallback sem metadata:** `/giveitem id backpack 1` usa o perfil padrão do modelo em `Config.DefaultProfileByModel`.

**Idiomas:** `locale/pt-br.lua` e `locale/en-us.lua` — `setr pr_bridge:locale pt-br`

---

## Notas

- Modelos novos → admin cria → **F8** gera snippet → cadastrar no inventário
- Perfis ilimitados via `metadata.profile`
- Cada mochila usada gera stash único em `metadata.stash`
- Loja NPC lista perfis com `shopEnabled: true`

---

## Suporte

**forge Devs / DOTINIT SCRIPTS** — https://discord.gg/52duTcAfx9




implementaçoes a fazer:

1. impossibilitar o player de ter mais mochilas que na Config.MaxBackpack.

2. Impossibilitar de por determinados itens dentro da mochila Config.BlacklistItems.

