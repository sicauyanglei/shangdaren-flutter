import { Card, CardDefinition, CARD_DEFINITIONS } from '../types';

let cardIdCounter = 0;

export function createCard(definition: CardDefinition): Card {
  const id = `${definition.character}-${++cardIdCounter}`;
  
  return {
    id,
    definition,
    get character() { return definition.character; },
    get sentence() { return definition.sentence; },
    get position() { return definition.position; },
    get color() { return definition.color; },
    get isSpecial() { return definition.isSpecial; },
    get baseHu() { return definition.baseHu; }
  };
}

export function resetCardIdCounter(): void {
  cardIdCounter = 0;
}
