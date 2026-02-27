import csv
import json
import os
import glob
import re

def to_snake_case(name):
    name = re.sub(r'[^a-zA-Z0-9]+', '_', name)
    return name.strip('_').lower()

def load_json(filepath):
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            return json.load(f)
    except FileNotFoundError:
        return None

def save_json(filepath, data):
    with open(filepath, 'w', encoding='utf-8') as f:
        json.dump(data, f, indent=2)

def update_pokemon():
    print("Updating Pokemon...")
    if not os.path.exists('data/pokemon'):
        os.makedirs('data/pokemon')
        
    csv_rows = []
    with open('all_pokemon.csv', 'r', encoding='utf-8-sig') as f:
        reader = csv.DictReader(f)
        for row in reader:
            csv_rows.append(row)
            
    for row in csv_rows:
        # Some names are "Charizard\nMega Charizard X". We want "Mega Charizard X".
        name = row['Name'].split('\n')[-1].strip()
        if not name: continue
        
        pkmn_id = to_snake_case(name)
        filepath = f"data/pokemon/{pkmn_id}.json"
        
        data = load_json(filepath)
        # If it's a manually corrupted mon that somehow shares a name, don't overwrite its stats
        if data and data.get('is_corrupted', False):
            continue
            
        if not data:
            data = {
                "id": pkmn_id,
                "name": name,
                "national_dex": int(row['#']),
                "types": [],
                "base_stats": {},
                "abilities": ["TBD"],
                "hidden_ability": None,
                "learnset": [],
                "evolution": None,
                "dex_entry": "TBD",
                "catch_rate": 45,
                "base_exp": 60,
                "growth_rate": "medium_slow",
                "egg_groups": ["TBD"],
                "gender_ratio": 50,
                "is_native_hoenn": False,
                "native_zone": None,
                "is_corrupted": False,
                "corruption_zone": None,
                "corruption_path": None,
                "base_species": None
            }
            
        # Update Types
        types = [t.strip() for t in row['Type'].split('\n') if t.strip()]
        data['types'] = types
        
        # Update Base Stats
        try:
            data['base_stats']['hp'] = int(row['HP'])
            data['base_stats']['atk'] = int(row['Attack'])
            data['base_stats']['def'] = int(row['Defense'])
            data['base_stats']['spa'] = int(row['Sp. Atk'])
            data['base_stats']['spd'] = int(row['Sp. Def'])
            data['base_stats']['spe'] = int(row['Speed'])
        except ValueError:
            pass # Handle empty fields if any
            
        # Update national dex if null
        if data.get('national_dex') is None:
            data['national_dex'] = int(row['#'])
            
        save_json(filepath, data)
    print("Pokemon update complete.")


def update_moves():
    print("Updating Moves...")
    if not os.path.exists('data/moves'):
        os.makedirs('data/moves')
    
    csv_rows = []
    with open('all_moves.csv', 'r', encoding='utf-8-sig') as f:
        reader = csv.DictReader(f)
        for row in reader:
            csv_rows.append(row)
            
    for row in csv_rows:
        name = row['Name'].strip()
        if not name: continue
        
        move_id = to_snake_case(name)
        filepath = f"data/moves/{move_id}.json"
        
        data = load_json(filepath)
        if not data:
            data = {
                "id": move_id,
                "name": name,
                "type": "Normal",
                "category": "physical",
                "power": None,
                "accuracy": 100,
                "pp": 10,
                "priority": 0,
                "target": "single_opponent",
                "effect": None,
                "flags": [],
                "description": "",
                "is_custom": False
            }
            
        data['type'] = row['Type'].strip()
        
        cat = row['Category'].strip()
        if cat in ['Physical', 'Special', 'Status']:
            data['category'] = cat.lower()
            
        power = row['Power'].strip()
        if power.isdigit():
            data['power'] = int(power)
        elif power in ['—', 'None']:
            data['power'] = None
            
        acc = row['Accuracy'].strip().replace('%', '')
        if acc.isdigit():
            data['accuracy'] = int(acc)
        elif acc in ['—', '∞', 'None']:
            data['accuracy'] = None
            
        pp = row['PP'].strip()
        if pp.isdigit():
            data['pp'] = int(pp)
            
        # If creating new, set the description from CSV if available (Effect column no longer present)
        # We'll just leave description blank if new, since this CSV doesn't have it.
                
        save_json(filepath, data)
    print("Moves update complete.")


def sync_abilities():
    print("Generating/Updating Abilities...")
    if not os.path.exists('data/abilities'):
        os.makedirs('data/abilities')
        
    csv_rows = []
    with open('all_abilities.csv', 'r', encoding='utf-8-sig') as f:
        reader = csv.DictReader(f)
        for row in reader:
            csv_rows.append(row)
            
    # We will generate base JSON for all abilities in the CSV
    for row in csv_rows:
        name = row['Name'].strip()
        if not name: continue
        
        ability_id = to_snake_case(name)
        filepath = f"data/abilities/{ability_id}.json"
        
        if os.path.exists(filepath):
            data = load_json(filepath)
        else:
            data = {
                "id": ability_id,
                "name": name,
                "description": "",
                "hooks": []
            }
            
        data['name'] = name
        data['description'] = row['Description'].strip()
        
        # Save JSON
        save_json(filepath, data)
        print(f"Generated/Updated {filepath}")


if __name__ == "__main__":
    update_pokemon()
    update_moves()
    sync_abilities()
