**BIBLE DE GAME DESIGN**

**Natures • Clans • Sub-jutsu**

180 techniques --- V1 combat PvP

Document de conception détaillé : mécaniques, activation, synergies et
contre-jeu.\
Les valeurs de dégâts, coûts et cooldowns sont volontairement laissées à
l'équilibrage ; les mécaniques décrites ici constituent le cœur
fonctionnel des sorts.

# 1. Principes de conception

**Pas de "même sort, autre couleur" ---** Chaque technique doit modifier
une décision de combat : trajectoire, timing, ressource, vision, espace,
position, état, lecture ou risque. Deux sorts de même rang d'une Nature
répondent à deux besoins réellement différents.

**Mécanique avant chiffres ---** Les dégâts, coûts en chakra, cooldowns
et durées exactes sont des variables d'équilibrage. Une technique doit
rester intéressante même si ses dégâts sont baissés de 20 %, car son
identité vient d'abord de son fonctionnement.

**Contre-jeu obligatoire ---** Aucun contrôle important ne doit être
sans réponse. Le contre peut être une esquive, une destruction d'objet,
la rupture de ligne de vue, une lecture de télégraphe, la sortie d'une
zone, la gestion d'une ressource ou la punition d'une récupération.

**Préparation récompensée ---** Les rangs élevés exploitent souvent ce
qui a été préparé par les rangs inférieurs : marques, terrain, ancres,
charges ou invocations. Le joueur expérimenté doit pouvoir construire
une séquence plutôt que simplement lancer son plus gros sort dès qu'il
revient.

**Hard-CC rare et court ---** Les immobilisations, freezes et captures
sont conditionnels, préparés et brefs. Le contrôle principal vient du
déplacement forcé, des barrières poreuses, des menaces de zone, des
ressources et des changements de trajectoire.

**Serveur et implémentation ---** Chaque objet persistant --- miroir,
marionnette, glyphe, ancre, nœud, clone, zone --- doit avoir un
identifiant serveur, une durée, des règles de destruction et un
propriétaire. Les recasts doivent référencer explicitement l'instance
créée par le premier cast.

# 2. États et vocabulaire commun

**Recast :** Second appui sur la même technique avant expiration d'une
fenêtre définie.

**Tether :** Lien à portée limitée qui se rompt par distance, obstacle
ou destruction de son ancre.

**Domaine :** Grande zone temporaire qui modifie les règles locales mais
possède toujours une sortie ou un objet destructible.

**Sweet spot :** Partie plus exigeante d'une hitbox offrant une
meilleure récompense que le simple contact.

**Armor / ténacité :** Résistance au déplacement ou à l'interruption ;
ne signifie pas invulnérabilité aux dégâts.

**Marque :** État lisible posé sur une cible et utilisé comme condition
par d'autres techniques.

**Objet persistant :** Élément physique de gameplay avec durée/PV : mur,
miroir, glyphe, marionnette, nœud, etc.

# 3. Vue d'ensemble du contenu

  -----------------------------------------------------------------------
  Famille           Kits              Techniques        Structure
  ----------------- ----------------- ----------------- -----------------
  Natures           5                 50                2 sorts par rang
                                                        D/C/B/A/S

  Clans             20                100               1 sort par rang
                                                        D/C/B/A/S

  Sub-jutsu         Pool global       30                12 rang B • 10
                                                        rang A • 8 rang S

  TOTAL                               180               
  -----------------------------------------------------------------------

# 4. Natures élémentaires --- 50 techniques

## Katon

**Identité :** Katon est la nature de la pression et de l\'escalade. Ses
techniques créent des Braises et des zones de Cendres. Les Braises sont
des marqueurs temporaires posés sur les ennemis ou le terrain ;
certaines techniques les allument pour produire un second effet. Le
Katon récompense donc la préparation, l\'enfermement d\'une cible et la
lecture de ses chemins de fuite plutôt que le simple spam de
projectiles.

**Mécanique signature :** Mécanique centrale --- Braise / Ignition : une
cible peut porter jusqu\'à 3 Braises. Une Ignition consomme toutes les
Braises et améliore son effet selon le nombre consommé. Les zones de
Cendres n\'infligent presque rien seules, mais servent de combustible à
plusieurs techniques.

**D --- Braise traçante**

**Tags :** Projectile, Marque, Poke

**Activation et fonctionnement :** Le lanceur souffle un petit noyau
incandescent rapide. À l'impact, les dégâts sont faibles mais une Braise
est fixée à la cible pendant quelques secondes. Si le projectile manque,
il reste au sol comme une petite Braise de terrain.

**Mécanique réelle :** Le projectile possède une légère correction de
trajectoire uniquement contre une cible déjà visible au moment du lancer
; il ne tourne pas derrière un obstacle. Une cible portant la Braise
devient la meilleure amorce du kit : toute future Ignition provoque en
plus une micro-explosion autour d'elle.

**Synergies / intérêt :** Permet de préparer Comète incendiaire, Prison
thermique ou Fournaise solaire. Les Braises au sol peuvent aussi être
poussées ou dispersées par certains effets de vent.

**Contre-jeu :** Le projectile est volontairement peu dangereux seul :
esquive latérale, couvert ou purge d'état. La Braise est visible et
indique clairement au joueur qu'un combo Katon est en préparation.

**D --- Souffle de recul**

**Tags :** Cône, Anti-melee, Zone

**Activation et fonctionnement :** Après de courts mudras, le lanceur
expulse une gerbe très courte devant lui. Elle inflige peu de dégâts,
repousse fortement les ennemis proches et recouvre le sol d'une bande de
Cendres.

**Mécanique réelle :** Le centre du cône repousse plus loin que les
bords. Une cible déjà en train d'attaquer au corps à corps est
brièvement déséquilibrée plutôt que simplement déplacée. La bande de
Cendres reste quelques secondes et peut être embrasée par une autre
technique.

**Synergies / intérêt :** Excellent outil de désengagement qui
transforme ensuite la distance créée en espace dangereux. Une Braise
traçante tirée dans les Cendres peut créer un point d'Ignition à
distance.

**Contre-jeu :** Portée très courte, dégâts modestes et préparation
lisible. Un adversaire qui feinte son entrée peut faire partir le sort
dans le vide puis engager pendant son cooldown.

**C --- Anneau de cendres**

**Tags :** Zone, Piège, Contrôle

**Activation et fonctionnement :** Le lanceur dessine rapidement un
cercle de Cendres autour d'un point ciblé. Le cercle est traversable,
mais le premier ennemi qui franchit son bord reçoit une Braise et laisse
une traînée de pas incandescents derrière lui.

**Mécanique réelle :** L'intérieur du cercle n'est pas une prison : la
menace vient du bord. Si une Ignition survient sur un porteur de Braise
à l'intérieur, le bord du cercle flambe brièvement et repousse vers le
centre ceux qui tentent de sortir exactement à ce moment.

**Synergies / intérêt :** Crée une vraie situation de duel : enfermer
quelqu'un avec Prison thermique, forcer un dash, ou provoquer une
mauvaise sortie avec Souffle de recul.

**Contre-jeu :** Le cercle est visible dès sa création, possède une
durée limitée et n'empêche jamais une sortie. Une mobilité bien
temporisée traverse avant l'embrasement ; un ennemi peut aussi
simplement combattre hors du cercle.

**C --- Comète incendiaire**

**Tags :** Projectile chargé, Burst, Recast

**Activation et fonctionnement :** Le joueur charge une boule de feu
lourde puis la lance en cloche. Un second appui pendant le vol la fait
éclater prématurément en trois fragments plus petits qui continuent dans
un éventail.

**Mécanique réelle :** La boule principale inflige un impact moyen et
crée une zone brûlante. Si elle touche une cible portant au moins 2
Braises, elle les consomme pour provoquer une explosion verticale qui
projette brièvement la cible vers le haut. Les fragments n'ont pas cette
propriété mais couvrent davantage d'espace.

**Synergies / intérêt :** Le choix entre projectile lourd et éclatement
fait du sort un outil de lecture. Anneau de cendres aide à prédire
l'esquive ; Braise traçante débloque le launcher.

**Contre-jeu :** Charge visible et projectile destructible ou évitable.
Faire éclater trop tôt réduit nettement le potentiel mono-cible. Le
lanceur est ralenti pendant la charge.

**B --- Prison thermique**

**Tags :** Dôme, Contrôle, Anti-heal

**Activation et fonctionnement :** Le lanceur pose un noyau au sol ;
après un court délai, une cloche de chaleur semi-transparente apparaît
autour de la zone. Les personnages peuvent traverser la paroi, mais
chaque traversée applique une Braise et un bref ralentissement.

**Mécanique réelle :** À l'intérieur, les soins reçus sont légèrement
réduits et les Braises expirent moins vite. Si une Ignition consomme 3
Braises dans le dôme, la paroi pulse et repousse tous les ennemis vers
l'intérieur une seule fois.

**Synergies / intérêt :** Transforme le Katon en contrôleur d'espace
sans hard-stun permanent. Anneau de cendres superposé produit plusieurs
chemins de sortie coûteux ; Souffle de recul peut renvoyer quelqu'un
dans le dôme.

**Contre-jeu :** Le noyau est destructible avant l'ouverture complète.
La prison n'est jamais solide : un adversaire peut payer le coût d'une
traversée pour sortir. Le dôme est particulièrement faible si le lanceur
ne possède aucune Braise à exploiter.

**B --- Lance de verre**

**Tags :** Skillshot, Perforation, Anti-armure

**Activation et fonctionnement :** Le lanceur condense un trait de feu
extrêmement fin puis le projette en ligne droite. La première surface de
terrain touchée est vitrifiée pendant quelques secondes ; les
protections temporaires et boucliers subissent des dégâts
supplémentaires.

**Mécanique réelle :** Contre une cible portant une Braise, la lance la
fait éclater sans consommer les autres : elle ouvre ainsi une petite
fenêtre de Fracture thermique qui réduit brièvement la résistance au
prochain coup, mais ne provoque pas le burst d'une vraie Ignition.

**Synergies / intérêt :** C'est le choix B orienté précision : Braise
traçante facilite la préparation, puis Lance de verre punit une armure
ou un rempart. Très forte avec une équipe qui sait exploiter la courte
Fracture.

**Contre-jeu :** Hitbox étroite, pas d'explosion et télégraphe sonore
aigu. Un dash latéral suffit. Le lanceur reste brièvement immobile au
moment du tir, ce qui permet le contre-poke.

**A --- Mer de flammes**

**Tags :** Terrain, Propagation, Zoning

**Activation et fonctionnement :** Le joueur enflamme une zone de
Cendres ou un point de sol. Le feu se propage ensuite lentement vers les
zones de Cendres adjacentes et suit les traces de pas incandescentes
créées par Anneau de cendres.

**Mécanique réelle :** La propagation n'est pas instantanée : elle
dessine un front de flammes visible. Un ennemi qui reste dans le feu
accumule des Braises plus vite mais ne subit pas un stun. Le lanceur
peut réactiver une fois la technique pour arrêter la propagation et
faire exploser uniquement le bord actuel.

**Synergies / intérêt :** Transforme la préparation du terrain des rangs
D/C en menace de haut niveau. Le joueur Katon peut construire son propre
labyrinthe de propagation plutôt que poser une simple AOE géante.

**Contre-jeu :** Les zones sans Cendres limitent fortement la portée.
Sortir du front avant qu'il arrive est la réponse principale. Les effets
qui nettoient ou déplacent les zones au sol cassent la chaîne.

**A --- Phénix à rebond**

**Tags :** Multi-projectile, Recast, Pression

**Activation et fonctionnement :** Trois oiseaux de feu sont lancés
successivement. Chaque oiseau qui frappe un mur, un bouclier ou une
cible peut rebondir une fois. Après le premier rebond, le joueur peut
appuyer à nouveau pour orienter tous les oiseaux encore actifs vers un
nouveau point.

**Mécanique réelle :** Un oiseau qui traverse une Braise au sol
l'emporte avec lui. S'il touche ensuite un ennemi, cette Braise est
appliquée immédiatement. Deux oiseaux ne peuvent pas infliger leur plein
burst au même instant : le système impose un léger espacement de dégâts
pour préserver le contre-jeu.

**Synergies / intérêt :** Très fort dans les espaces fermés et autour
des zones préparées. Le recast permet de convertir un tir de zoning en
attaque de flanc.

**Contre-jeu :** Les oiseaux sont visibles, destructibles par certaines
défenses et perdent beaucoup de valeur en terrain ouvert. Le recast ne
corrige pas une mauvaise position initiale.

**S --- Fournaise solaire**

**Tags :** Finisher, Détonation globale, Risque

**Activation et fonctionnement :** Le lanceur canalise brièvement puis
tente d'Igniter simultanément toutes ses Braises actives sur ennemis et
terrain dans une grande zone. Chaque point explose séparément ; plus les
Braises sont espacées, plus la zone totale couverte est grande.

**Mécanique réelle :** Une même cible ne peut subir qu'un nombre limité
d'explosions directes, mais les détonations peuvent se chevaucher pour
créer des corridors dangereux. À 3 Braises sur une cible, l'explosion
finale devient une éruption verticale qui interrompt les canalisations.

**Synergies / intérêt :** C'est l'aboutissement du gameplay de
préparation : un Katon qui a marqué plusieurs personnes et préparé le
terrain obtient un S spectaculaire. Utiliser Mer de flammes avant peut
forcer des positions idéales.

**Contre-jeu :** Canalisation très identifiable ; si le lanceur est
interrompu avant le flash final, aucune Braise n'est consommée mais le
sort passe sur un cooldown partiel. Sans préparation préalable, le S est
volontairement médiocre.

**S --- Dragon de feu dévorant**

**Tags :** Invocation dirigée, Absorption, Recast

**Activation et fonctionnement :** Le joueur invoque un dragon de feu
qu'il dirige pendant quelques secondes avec son viseur. Le dragon avance
continuellement, inflige des dégâts sur contact et peut avaler les
petits projectiles non ultimes qu'il rencontre.

**Mécanique réelle :** Chaque projectile avalé augmente une jauge de
Gueule ardente. Le joueur peut réactiver pour faire plonger le dragon
sur une zone ; la taille de l'explosion dépend de la jauge. Avaler une
Braise de terrain compte comme une petite charge et permet de courber
légèrement la trajectoire.

**Synergies / intérêt :** S orienté maîtrise mécanique et anti-zoning.
Il peut protéger une avancée alliée, nettoyer une salve de projectiles
puis convertir cette défense en attaque.

**Contre-jeu :** Pendant le contrôle, le lanceur se déplace lentement et
reste vulnérable. Les attaques de mêlée, rayons lourds et ultimes ne
sont pas avalés. Le dragon possède une durée maximale stricte.

## Suiton

**Identité :** Suiton contrôle les trajectoires et le tempo. Il crée des
surfaces d'Eau et applique l'état Trempé. Le joueur ne cherche pas
seulement à ralentir : il utilise l'eau comme infrastructure de combat,
pour modifier ses déplacements, déplacer les ennemis et changer l'angle
de ses techniques.

**Mécanique signature :** Mécanique centrale --- Trempé / Eau : Trempé
n'est pas un debuff massif à lui seul. Il sert de condition à plusieurs
effets et reste lisible. Les surfaces d'Eau persistent quelques secondes
; le lanceur Suiton peut glisser dessus plus vite et certaines
techniques changent de forme lorsqu'elles les traversent.

**D --- Aiguille de pression**

**Tags :** Hitscan court, Poke, Marque

**Activation et fonctionnement :** Une micro-lance d'eau extrêmement
rapide est tirée après un bref geste. Elle inflige de faibles dégâts
mais applique Trempé. Si la cible est déjà Trempée, l'aiguille la
traverse et peut toucher une seconde cible derrière.

**Mécanique réelle :** La portée est moyenne et la largeur minuscule :
c'est un outil de précision. Sur une surface d'Eau, le tir gagne
légèrement en longueur et laisse un petit sillage visuel.

**Synergies / intérêt :** Prépare presque tout le kit. La perforation
récompense l'alignement des ennemis plutôt que le simple focus
mono-cible.

**Contre-jeu :** Faible dégâts et aucune zone. Une cible attentive peut
jouer hors de l'axe ou derrière un vrai couvert.

**D --- Pas de surface**

**Tags :** Mobilité, Terrain, Recast

**Activation et fonctionnement :** Le lanceur glisse rapidement dans la
direction choisie en laissant une fine bande d'Eau derrière lui. S'il
termine sur une surface d'Eau existante, il conserve une charge de
recast très courte permettant un second petit pas.

**Mécanique réelle :** Le second pas ne peut pas retraverser exactement
la même zone et n'accorde pas d'invulnérabilité. Un ennemi touché par le
sillage devient Trempé mais n'est pas renversé.

**Synergies / intérêt :** Permet de construire soi-même des rails de
mobilité pour les techniques ultérieures et de repositionner un duel.

**Contre-jeu :** Trajectoire rectiligne, pas de traversée de murs et
vulnérabilité à l'anticipation. Le recast disparaît vite.

**C --- Sphère de rupture**

**Tags :** Projectile, Knockback, Terrain

**Activation et fonctionnement :** Une sphère d'eau compacte avance
lentement. Au premier contact avec un ennemi ou sur recast, elle éclate
et pousse tout ce qui se trouve autour du point d'explosion.

**Mécanique réelle :** Si la sphère traverse une surface d'Eau, elle
grossit légèrement et son explosion laisse une flaque. Une cible Trempée
est poussée davantage mais ne subit pas plus de dégâts.

**Synergies / intérêt :** Permet de créer ou casser un alignement,
pousser quelqu'un dans une zone alliée, ou libérer un coéquipier. Pas de
surface peut préparer sa croissance.

**Contre-jeu :** Projectile lent et destructible. L'explosion est
annoncée par une dilatation visuelle juste avant le burst.

**C --- Rideau réfringent**

**Tags :** Mur, Défense, Déviation

**Activation et fonctionnement :** Le lanceur dresse une paroi d'eau
verticale durant un court instant. Les petits projectiles qui la
traversent ne sont pas annulés : leur trajectoire est déviée selon
l'angle d'incidence.

**Mécanique réelle :** Le joueur peut orienter le rideau au placement.
Les projectiles alliés subissent aussi la réfraction, ce qui permet des
tirs courbes préparés. Les rayons et attaques de mêlée traversent
normalement.

**Synergies / intérêt :** Technique de haut skill-cap : défendre un
allié, rater volontairement un tir pour le courber, ou créer une menace
depuis un angle impossible.

**Contre-jeu :** Durée courte, orientation figée après placement et
aucune protection contre les attaques de zone, rayons ou mêlée.

**B --- Prison aqueuse**

**Tags :** Canalisation, Tether, Duel

**Activation et fonctionnement :** Un jet d'eau relie le lanceur à une
cible proche. Si le lien reste intact un court moment, une bulle se
forme autour de la cible et réduit fortement sa vitesse de déplacement
tout en l'empêchant de franchir certains petits obstacles.

**Mécanique réelle :** Le lanceur doit maintenir la canalisation et peut
se déplacer lentement. La prison n'est pas un hard-stun : la cible peut
attaquer, casser la ligne de vue ou infliger assez de pression au
lanceur. Un allié peut également frapper la bulle pour la rompre.

**Synergies / intérêt :** Excellent contrôle d'une cible Trempée, car le
temps nécessaire à la formation est légèrement réduit. Sert surtout à
créer une fenêtre pour l'équipe.

**Contre-jeu :** Très exposé aux interruptions et au focus. Briser la
ligne de vue avant fermeture annule la prison.

**B --- Torrent de renversement**

**Tags :** Vague, Déplacement forcé, Recast

**Activation et fonctionnement :** Une vague basse part du lanceur et
avance en ligne. Au premier passage elle emporte légèrement les ennemis
dans son sens. Le joueur peut réactiver une fois pour rappeler l'eau
vers lui.

**Mécanique réelle :** Les ennemis touchés à l'aller puis au retour sont
brièvement renversés au second contact. Le retour suit le chemin réel de
la vague et contourne mal les obstacles, donc le placement initial
compte beaucoup.

**Synergies / intérêt :** Crée des combos de déplacement uniques :
pousser une cible derrière soi puis la rappeler, ou nettoyer une zone
pour protéger un allié.

**Contre-jeu :** La vague est visible et le renversement exige deux
touches. Une cible qui s'écarte du corridor après le premier passage
évite la partie forte.

**A --- Miroir liquide**

**Tags :** Contre, Copie, Recast

**Activation et fonctionnement :** Le lanceur crée devant lui un disque
d'eau pendant une très courte fenêtre. Le premier projectile ou
technique linéaire compatible absorbé est enregistré. Un second appui,
dans les quelques secondes suivantes, renvoie une copie aqueuse du même
profil de trajectoire.

**Mécanique réelle :** La copie reproduit la forme et la vitesse, pas
les mécaniques exclusives du sort d'origine : elle inflige des dégâts
Suiton et applique Trempé. Les ultimes, invocations et zones
persistantes ne peuvent pas être enregistrés.

**Synergies / intérêt :** Permet un véritable mindgame : l'adversaire
peut refuser de lancer son gros skillshot, tandis que le Suiton gagne
une réponse adaptable.

**Contre-jeu :** Fenêtre de parade courte et directionnelle. Si rien
n'est capté, le sort est perdu. La copie est moins puissante que
l'original et clairement teintée d'eau.

**A --- Marée captive**

**Tags :** Grande zone, Courant, Contrôle

**Activation et fonctionnement :** Une zone circulaire se remplit
progressivement d'une faible hauteur d'eau. À l'intérieur, le lanceur
choisit périodiquement une direction de courant ; tous les personnages
sont lentement entraînés dans ce sens.

**Mécanique réelle :** Les ennemis Trempés subissent davantage le
courant, tandis que le lanceur et ses alliés conservent plus de
contrôle. Les dashes fonctionnent normalement et permettent de lutter
contre le flux.

**Synergies / intérêt :** C'est un contrôle spatial souple : il ne
bloque pas, mais transforme toutes les trajectoires et facilite les
skillshots ou les sorties ratées.

**Contre-jeu :** Montée de l'eau annoncée, zone fixe et aucun burst
initial. Quitter la zone est toujours possible avec une bonne mobilité.

**S --- Léviathan de pression**

**Tags :** Invocation dirigée, Capture, Recast

**Activation et fonctionnement :** Un serpent d'eau massif naît au point
ciblé et suit une trajectoire dirigée par le viseur pendant quelques
secondes. Les ennemis frappés sont emportés brièvement dans son corps
puis relâchés derrière lui.

**Mécanique réelle :** Le joueur peut réactiver pour faire plonger le
Léviathan et exploser en geyser. Plus il a transporté de cibles ou
traversé de surfaces d'Eau, plus le geyser est large, sans augmenter
indéfiniment les dégâts.

**Synergies / intérêt :** S spectaculaire de déplacement d'équipe : il
peut séparer une frontline, sauver un allié en emportant ses
poursuivants ou préparer une zone de burst.

**Contre-jeu :** Le Léviathan tourne avec inertie, ne traverse pas les
gros murs et le lanceur est ralenti pendant la conduite. Les cibles ne
sont transportées qu'un temps limité.

**S --- Domaine des profondeurs**

**Tags :** Domaine, Mobilité, Vision

**Activation et fonctionnement :** Le lanceur inonde une vaste zone
d'une nappe sombre. Tous les personnages à l'intérieur sont considérés
Trempés. Les bruits de déplacement génèrent des ondulations visibles
pour le lanceur, tandis que les contours au-delà d'une certaine distance
deviennent moins nets pour tout le monde.

**Mécanique réelle :** Le Suiton peut utiliser Pas de surface sans
consommer son recast bonus dans le domaine, mais seulement à intervalles
espacés. Les ennemis peuvent volontairement rester immobiles pour ne pas
produire d'ondulation, créant un jeu de chasse.

**Synergies / intérêt :** Ultime de contrôle de l'information et de
mobilité, pas une simple AOE de dégâts. Idéal pour isoler les duels et
exploiter les tirs précis.

**Contre-jeu :** Le domaine est fixe, ne rend personne invisible et les
attaques révèlent immédiatement leur origine. Quitter la zone annule ses
avantages.

## Raiton

**Identité :** Raiton est une nature de tempo explosif. Elle applique
des Charges conductrices sur les ennemis ou le terrain, puis les utilise
pour créer des déplacements instantanés, des arcs ou des contrôles
brefs. Le kit récompense la précision et les fenêtres courtes plutôt que
les stuns permanents.

**Mécanique signature :** Mécanique centrale --- Charge : une cible peut
porter jusqu'à 3 Charges. Certaines techniques les consomment, d'autres
les propagent. Les contrôles électriques sont très courts mais peuvent
interrompre une canalisation. Les Charges expirent vite afin d'obliger
le joueur à enchaîner ses décisions.

**D --- Aiguille voltaïque**

**Tags :** Hitscan, Marque, Interrupt

**Activation et fonctionnement :** Un éclair très fin frappe presque
instantanément dans une portée moyenne. Dégâts faibles, mais applique 1
Charge. Sur une cible déjà à 3 Charges, il ne rajoute rien : il provoque
à la place une micro-secousse capable d'interrompre un mudra long sans
stun complet.

**Mécanique réelle :** Le sort possède un bref délai entre clic et
impact, suffisant pour permettre une esquive si le joueur lit
l'animation.

**Synergies / intérêt :** Ouvre les combos et entretient les Charges
avant qu'elles expirent.

**Contre-jeu :** Faible largeur, faible dégâts et aucun splash. Un
joueur qui varie ses mouvements réduit fortement sa fiabilité.

**D --- Pas ionique**

**Tags :** Dash, Cible conditionnelle, Reposition

**Activation et fonctionnement :** Le lanceur effectue un court dash.
S'il termine à proximité d'une cible chargée, il peut orienter
automatiquement la fin de course autour d'elle, comme une orbite, sans
la traverser.

**Mécanique réelle :** Le dash laisse au point de départ un résidu
électrique d'une seconde ; un ennemi qui le traverse reçoit 1 Charge. Il
n'accorde pas d'invulnérabilité complète.

**Synergies / intérêt :** Crée un jeu de flanc autour d'une cible
préparée et permet d'utiliser les résidus comme mini-pièges.

**Contre-jeu :** Distance modeste, trajectoire finale lisible et risque
élevé contre les AOE posées autour de la cible.

**C --- Arc sauteur**

**Tags :** Chaîne, Propagation, Choix de cible

**Activation et fonctionnement :** Un éclair frappe une cible ou un
point chargé puis cherche jusqu'à deux nouvelles cibles proches. Chaque
saut inflige moins de dégâts mais transporte 1 Charge.

**Mécanique réelle :** Le joueur peut viser le sol chargé pour lancer la
chaîne depuis un angle inattendu. Une même cible ne peut être frappée
qu'une fois par cast.

**Synergies / intérêt :** Excellent pour répandre les Charges dans un
groupe avant Cage de foudre ou Cataclysme.

**Contre-jeu :** Faible valeur contre une cible isolée et portée de saut
visible. Écarter la formation réduit fortement l'effet.

**C --- Garde statique**

**Tags :** Parade, Stockage, Recast

**Activation et fonctionnement :** Le lanceur prend une garde électrique
très courte. Si une attaque directe le touche pendant la fenêtre, une
partie des dégâts est réduite et l'énergie est stockée dans un
Condensateur.

**Mécanique réelle :** Un second appui libère le Condensateur sous forme
d'onde courte. Plus l'attaque absorbée était lourde, plus l'onde
repousse ; les dégâts restent plafonnés pour éviter de retourner un
ultime intégralement.

**Synergies / intérêt :** Donne au Raiton un vrai outil de lecture
défensive, puis convertit une bonne parade en setup offensif.

**Contre-jeu :** Fenêtre courte et directionnelle. Les dégâts
persistants, pièges au sol et attaques venant de dos ne déclenchent pas
correctement la garde.

**B --- Lance magnétique**

**Tags :** Skillshot, Pull/Push, Consommation

**Activation et fonctionnement :** Une lance d'électricité magnétisée
part en ligne et s'accroche au premier ennemi touché. Le joueur choisit
immédiatement, via direction de déplacement, entre l'attirer légèrement
ou se tirer lui-même vers la cible.

**Mécanique réelle :** Chaque Charge consommée augmente la force du
déplacement, jusqu'à 3. Le sort n'étourdit pas : il change brutalement
la géométrie du duel.

**Synergies / intérêt :** Peut rapprocher un fuyard, créer un engage ou
servir de grappin offensif. Pas ionique permet ensuite de tourner autour
de la cible.

**Contre-jeu :** Skillshot étroit. Consommer toutes les Charges enlève
des ressources aux autres sorts ; un mauvais choix de traction peut
mettre le Raiton en danger.

**B --- Cage de foudre**

**Tags :** Piège, Barrière conditionnelle, Contrôle

**Activation et fonctionnement :** Le joueur plante quatre arcs
électriques autour d'une petite zone. Après un court délai, des liens
apparaissent entre les points. Traverser un lien consomme 1 Charge sur
la cible et provoque une secousse ; sans Charge, le lien n'inflige qu'un
ralentissement bref.

**Mécanique réelle :** La cage ne possède pas de mur physique. Les
points peuvent être détruits un à un, ouvrant des sorties.

**Synergies / intérêt :** Très forte après Arc sauteur : plusieurs
ennemis chargés doivent choisir entre rester groupés ou payer les
secousses pour sortir.

**Contre-jeu :** Télégraphe clair et points destructibles. Les dashes
qui franchissent un lien le déclenchent mais ne sont pas annulés.

**A --- Armure d'éclair**

**Tags :** Mode, Mêlée, Mobilité

**Activation et fonctionnement :** Le lanceur enveloppe son corps de
Raiton pendant une durée courte. Sa vitesse augmente, ses attaques de
mêlée gagnent une petite avancée et chaque troisième contact applique
une Charge.

**Mécanique réelle :** La jauge d'armure se vide plus vite si le joueur
subit des dégâts lourds. Réactiver volontairement termine le mode par
une décharge courte qui repousse, mais sacrifie le temps restant.

**Synergies / intérêt :** Transforme temporairement le kit en chasseur
mobile et donne un outil d'engagement aux builds qui ont choisi les
techniques de précision.

**Contre-jeu :** Coût de chakra continu, pas d'invulnérabilité et
vulnérabilité aux contrôles de zone. Forcer le Raiton à courir après une
cible gaspille le mode.

**A --- Tonnerre guidé**

**Tags :** Marque, Frappe retardée, Lecture

**Activation et fonctionnement :** Le lanceur désigne une cible visible.
Trois marqueurs d'orage apparaissent successivement au-dessus d'elle
puis frappent avec un délai régulier. La cible peut esquiver chaque
impact.

**Mécanique réelle :** Chaque Charge présente au moment du marquage
permet au prochain éclair de corriger légèrement son point d'impact vers
la dernière direction de déplacement observée. Les Charges sont
consommées une à une.

**Synergies / intérêt :** Crée un minijeu de poursuite : le Raiton peut
forcer des esquives, puis profiter des trajectoires prévisibles avec ses
autres skillshots.

**Contre-jeu :** Les cercles d'impact sont visibles au sol. Rompre la
ligne de vue après le marquage n'annule pas la série mais empêche toute
nouvelle correction.

**S --- Circuit Raijin**

**Tags :** Réseau, Téléportation, Combo

**Activation et fonctionnement :** Le lanceur transforme toutes ses
Charges actives sur ennemis et résidus au sol en Nœuds Raijin pendant
quelques secondes. Il peut alors se téléporter d'un nœud à l'autre avec
un très court délai interne.

**Mécanique réelle :** Chaque nœud ne peut être utilisé qu'une fois.
Arriver sur un nœud ennemi déclenche une frappe légère et place le
Raiton sur un côté prédictible de la cible, jamais directement dans son
modèle. La dernière téléportation crée une onde plus forte.

**Synergies / intérêt :** Ultime de maîtrise : plus le joueur a préparé
le terrain, plus son trajet peut être complexe. Il peut parcourir une
équipe ou revenir sur ses propres résidus.

**Contre-jeu :** Sans Charges préalables, le nombre de nœuds est très
faible. Les ennemis voient les nœuds et peuvent s'écarter avant
l'activation. Le joueur reste vulnérable entre deux sauts.

**S --- Cataclysme de l'orage**

**Tags :** Zone, Branches, Consommation de marques

**Activation et fonctionnement :** Le lanceur lève un orage sur une
large zone. À intervalles réguliers, un éclair frappe une cible chargée
ou, à défaut, le sol. Lorsqu'il touche une Charge, il se divise vers une
autre Charge proche.

**Mécanique réelle :** Chaque cible perd une Charge par frappe ; le sort
s'éteint donc naturellement s'il n'a pas été préparé. Les branches ne
peuvent pas rebondir indéfiniment sur les mêmes joueurs.

**Synergies / intérêt :** S de pression d'équipe qui récompense un
Raiton ayant marqué plusieurs cibles avec Arc sauteur et Cage de foudre.

**Contre-jeu :** Zone clairement délimitée, montée d'orage lente et
efficacité très réduite contre une équipe dispersée ou non chargée.

## Doton

**Identité :** Doton manipule le terrain et l'inertie. Son joueur crée
des structures, des lignes de faille et des fragments de roche qui
modifient la carte. Ce n'est pas seulement une nature défensive : elle
gagne les combats en fabriquant des angles, des obstacles et des zones
de vibration.

**Mécanique signature :** Mécanique centrale --- Strates / Fissures :
plusieurs techniques créent des Strates de terrain temporaire. Les
impacts lourds peuvent Fissurer ces Strates ; une technique ultérieure
peut alors les faire éclater ou s'en servir comme point d'origine. Les
structures ont des PV distincts et restent destructibles.

**D --- Schiste ricochet**

**Tags :** Projectile, Ricochet, Poke

**Activation et fonctionnement :** Un disque de pierre est lancé près du
sol. Il peut ricocher une fois sur un mur ou une structure Doton avant
de se briser. Après le rebond, sa vitesse et ses dégâts augmentent
légèrement.

**Mécanique réelle :** Le joueur voit brièvement une prévisualisation du
premier angle de rebond, pas du second trajet complet.

**Synergies / intérêt :** Récompense la création de murs et les angles
inattendus.

**Contre-jeu :** Faible valeur en terrain totalement ouvert ; le disque
reste esquivable et se détruit au second contact.

**D --- Ancrage tellurique**

**Tags :** Stance, Anti-CC, Stockage

**Activation et fonctionnement :** Le lanceur frappe le sol et s'ancre
pendant un court instant. Les déplacements forcés reçus sont fortement
réduits. Chaque poussée ou choc absorbé remplit une petite jauge
d'Impact.

**Mécanique réelle :** À la fin, l'Impact accumulé est relâché sous
forme d'un tremblement très court autour du joueur. Le sort n'absorbe
pas les dégâts eux-mêmes.

**Synergies / intérêt :** Permet de tenir une position et transforme les
tentatives de displacement adverses en menace locale.

**Contre-jeu :** Le lanceur se déplace lentement pendant l'ancrage et
reste vulnérable aux dégâts, poisons et attaques à distance.

**C --- Mur d'éperon**

**Tags :** Terrain, Cover, Launcher

**Activation et fonctionnement :** Une plaque de roche inclinée surgit
du sol. Elle bloque les projectiles et agit comme un petit obstacle
franchissable. Les personnages directement au-dessus lors de
l'apparition sont soulevés sur son côté le plus haut.

**Mécanique réelle :** Le mur peut servir de rampe. Une frappe lourde
sur sa base le Fissure ; une seconde le fait s'effondrer en gravats.

**Synergies / intérêt :** Crée des hauteurs, bloque des lignes de tir et
peut lancer une cible dans une trajectoire prévue.

**Contre-jeu :** Placement télégraphié par une fissure au sol ;
destruction possible et taille volontairement limitée.

**C --- Fosse d'argile**

**Tags :** Zone, Piège progressif, Terrain

**Activation et fonctionnement :** Le sol ciblé se ramollit
progressivement. La première seconde ralentit légèrement ; rester plus
longtemps augmente l'enfoncement jusqu'à une brève immobilisation des
pieds.

**Mécanique réelle :** Un dash sort normalement de la fosse. Si une
structure Doton s'effondre dedans, elle devient instantanément profonde
au centre mais sa durée totale diminue.

**Synergies / intérêt :** Force un choix : quitter tôt la zone ou
risquer une immobilisation. Synergie forte avec Mur d'éperon pour casser
les chemins de sortie.

**Contre-jeu :** Montée en puissance lente, zone clairement colorée et
aucune punition immédiate sur simple contact.

**B --- Armure lithique**

**Tags :** Bouclier segmenté, Ressource, Recast

**Activation et fonctionnement :** Trois plaques de pierre tournent
autour du lanceur. Chaque plaque absorbe une portion d'un impact
provenant de son côté puis se brise.

**Mécanique réelle :** Une plaque brisée tombe au sol comme Fragment. Le
joueur peut réactiver pour propulser tous les Fragments encore présents
vers le viseur, transformant la défense consommée en salve.

**Synergies / intérêt :** Crée une décision : garder les plaques pour
survivre ou accepter qu'elles cassent afin d'obtenir des munitions.

**Contre-jeu :** Les attaques répétées de faible puissance peuvent
dépouiller l'armure. Les zones qui frappent de plusieurs directions
contournent la protection segmentée.

**B --- Chambre sismique**

**Tags :** Deux ancres, Zone linéaire, Pulses

**Activation et fonctionnement :** Le joueur place un premier totem de
pierre puis un second. Une ligne sismique existe entre les deux et pulse
à intervalles fixes.

**Mécanique réelle :** Les ennemis sur la ligne au moment d'un pulse
subissent un choc et une très courte perte d'équilibre. Une Strate ou un
mur traversé par la ligne amplifie un pulse puis se Fissure.

**Synergies / intérêt :** Permet de construire une zone de contrôle qui
dépend réellement du placement de deux points et du terrain créé.

**Contre-jeu :** Détruire un totem supprime la chambre. Entre deux
pulses, la ligne n'empêche pas le passage.

**A --- Faille ascendante**

**Tags :** Ligne séquencée, Launcher, Terrain

**Activation et fonctionnement :** Une fissure se propage au sol en
segments successifs. Chaque segment explose vers le haut après un délai
légèrement différent, créant une vague de piliers plutôt qu'une seule
ligne instantanée.

**Mécanique réelle :** Le joueur peut réactiver une fois pour stopper la
propagation au segment actuel et faire éclater immédiatement les
segments restants déjà armés.

**Synergies / intérêt :** Permet de couper une retraite, jongler une
cible mal placée ou créer plusieurs Strates cassées pour les techniques
futures.

**Contre-jeu :** La séquence est lisible et un joueur peut courir
perpendiculairement à la ligne. Le recast raccourcit la portée totale.

**A --- Colosse de basalte**

**Tags :** Invocation, Copie d'action, Tank

**Activation et fonctionnement :** Un golem massif surgit du sol et
reste attaché à une petite zone. Il reproduit avec un léger délai la
direction des attaques de base du lanceur sous forme de grands coups de
pierre.

**Mécanique réelle :** Le golem possède ses propres PV. S'il meurt, il
s'effondre en plusieurs Fragments utilisables par Armure lithique. Il ne
poursuit pas les ennemis hors de sa zone.

**Synergies / intérêt :** Fait du Doton un combattant de position : le
joueur cherche à placer le duel dans la zone du golem et à synchroniser
ses frappes.

**Contre-jeu :** Très prévisible, immobile et destructible. Un
adversaire peut simplement forcer le combat ailleurs.

**S --- Citadelle mobile**

**Tags :** Fortification, Terrain majeur, Reconfiguration

**Activation et fonctionnement :** Quatre grandes plaques surgissent
autour d'une zone, créant une fortification ouverte. Le joueur peut, à
intervalles espacés, faire coulisser une plaque pour ouvrir ou fermer un
angle.

**Mécanique réelle :** Les plaques possèdent des PV et deviennent des
Strates. Elles ne peuvent jamais former une prison totalement hermétique
: au moins une sortie reste ouverte.

**Synergies / intérêt :** Ultime stratégique pour remodeler un point de
combat, protéger une résurrection, casser des lignes de tir ou canaliser
une équipe adverse.

**Contre-jeu :** Très peu de dégâts directs. Les structures peuvent être
détruites, et les combattants mobiles peuvent utiliser les ouvertures.

**S --- Cœur tellurique**

**Tags :** Noyau, Stockage d'impact, Détonation

**Activation et fonctionnement :** Le lanceur plante un Cœur de pierre.
Tous les impacts lourds, effondrements de structures et Fissures dans la
zone chargent progressivement le noyau, qu'ils viennent d'alliés ou
d'ennemis.

**Mécanique réelle :** Le joueur peut réactiver pour libérer l'énergie
en plusieurs anneaux sismiques successifs. La puissance vient du nombre
d'événements stockés, mais les dégâts sont plafonnés ; les charges
supplémentaires augmentent surtout le rayon et le nombre d'anneaux.

**Synergies / intérêt :** Transforme un combat chaotique autour de
structures en ressource. Le Doton peut volontairement sacrifier ses
propres murs pour le charger.

**Contre-jeu :** Le noyau est visible, destructible et ne se charge
presque pas si l'équipe refuse de combattre autour. Une destruction
ennemie provoque une petite décharge neutre au lieu de l'ultime complet.

## Fûton

**Identité :** Fûton est la nature des vecteurs et de la géométrie. Ses
dégâts viennent de coupes très lisibles, mais sa vraie force est de
modifier les trajectoires : pousser, aspirer, courber des projectiles et
fabriquer des couloirs de vitesse. C'est une nature de spacing et de
précision.

**Mécanique signature :** Mécanique centrale --- Courants : plusieurs
techniques créent brièvement un Courant orienté. Les projectiles et
personnages qui le traversent voient leur trajectoire influencée. Le
Fûton gagne à réfléchir en lignes et en angles plutôt qu'en zones
statiques.

**D --- Lame de sillage**

**Tags :** Boomerang, Skillshot, Double ligne

**Activation et fonctionnement :** Une lame de vent part en ligne puis
revient automatiquement au lanceur après une courte distance. L'aller et
le retour peuvent toucher séparément la même cible, mais le second
impact inflige moins de dégâts.

**Mécanique réelle :** Le joueur peut se déplacer pendant le retour :
modifier sa position modifie donc l'angle de la deuxième ligne.

**Synergies / intérêt :** Très simple à comprendre mais riche :
l'objectif est souvent de rater légèrement l'aller pour créer un retour
difficile à lire.

**Contre-jeu :** Projectile fin et trajectoire initiale évidente. Un
adversaire qui suit le déplacement du lanceur peut prédire le retour.

**D --- Paume de pression**

**Tags :** Cône, Push/Pull, Contrôle directionnel

**Activation et fonctionnement :** Une paume libère un cône de pression.
Maintenir avant de relâcher inverse l'effet : clic rapide repousse,
maintien court aspire légèrement.

**Mécanique réelle :** Les dégâts sont minimes ; la valeur vient du
déplacement. Une cible contre un obstacle subit une micro-perte
d'équilibre mais pas de stun long.

**Synergies / intérêt :** Permet de repositionner pour Lame de sillage,
sortir quelqu'un d'un couvert ou ramener une cible dans une coupe.

**Contre-jeu :** Portée courte et animation différente entre poussée et
aspiration, donc lisible pour un joueur attentif.

**C --- Fil du vide**

**Tags :** Skillshot retardé, Coupe, Anti-projectile

**Activation et fonctionnement :** Le joueur trace une ligne très fine
dans l'air. Après un bref délai, la ligne se contracte et coupe tout ce
qui la traverse.

**Mécanique réelle :** Au moment exact de la contraction, les petits
projectiles qui croisent la ligne sont détruits. Le centre de la ligne
constitue une zone de précision qui inflige davantage de dégâts aux
ennemis.

**Synergies / intérêt :** Outil de prédiction et de défense active.
Paume de pression peut forcer quelqu'un à retraverser la ligne au bon
moment.

**Contre-jeu :** La ligne est visible avant fermeture. Un adversaire
patient peut attendre la contraction puis passer.

**C --- Ascendance**

**Tags :** Colonne d'air, Mobilité verticale, Terrain

**Activation et fonctionnement :** Une colonne ascendante apparaît au
point ciblé. Les personnages qui entrent sont soulevés progressivement,
mais conservent leur contrôle horizontal.

**Mécanique réelle :** Le Fûton peut utiliser la colonne pour gagner un
tir plongeant ; un ennemi peut aussi l'exploiter, ce qui en fait un
outil neutre bien placé. Les projectiles verticaux sont légèrement
accélérés dans le courant.

**Synergies / intérêt :** Crée une vraie dimension verticale et des
opportunités d'angle pour Lame de sillage et Fil du vide.

**Contre-jeu :** La colonne ne piège personne et peut aider l'ennemi si
elle est mal placée. Zone fixe et durée courte.

**B --- Orbite tranchante**

**Tags :** Aura directionnelle, Anti-projectile, Mêlée

**Activation et fonctionnement :** Un anneau de vent tourne autour du
lanceur. Les petits projectiles qui entrent dans l'anneau sont déviés
tangentiellement plutôt qu'annulés.

**Mécanique réelle :** Les ennemis au corps à corps sont frappés par de
petites coupes répétées, mais l'anneau possède une ouverture mobile
derrière le lanceur ; il faut orienter son personnage pour défendre le
bon côté.

**Synergies / intérêt :** Défense active qui dépend du facing. Peut
renvoyer indirectement un projectile vers un autre adversaire ou dégager
un passage.

**Contre-jeu :** Ouverture arrière exploitable, durée limitée et
inefficace contre rayons, grosses AOE et attaques de mêlée lourdes.

**B --- Tornade de prise**

**Tags :** Vortex mobile, Pull, Projectile manipulation

**Activation et fonctionnement :** Une petite tornade avance lentement
dans la direction visée. Elle aspire légèrement les personnages proches
et capture les petits projectiles qu'elle croise.

**Mécanique réelle :** À sa fin ou sur recast, les projectiles capturés
sont relâchés en spirale autour du point de disparition, sans changer de
propriétaire.

**Synergies / intérêt :** Crée un objet mobile dangereux dont tout le
monde doit tenir compte. Peut détourner une salve ennemie puis la
relâcher ailleurs.

**Contre-jeu :** Très lente, visible et ses projectiles capturés peuvent
devenir dangereux pour le lanceur lui-même. Les gros projectiles ne sont
pas capturés.

**A --- Pas du faucon**

**Tags :** Mobilité aérienne, Recast, Assaut

**Activation et fonctionnement :** Le lanceur effectue une impulsion
diagonale dans les airs. Tant qu'il n'a pas touché le sol, un recast
permet une seconde impulsion perpendiculaire à la première.

**Mécanique réelle :** La première attaque offensive après la seconde
impulsion gagne une petite poussée directionnelle et crée un Courant
derrière le Fûton.

**Synergies / intérêt :** Outil de flanc tridimensionnel qui récompense
le contrôle aérien et la création d'angles.

**Contre-jeu :** Aucune invulnérabilité et trajectoires visibles. Si le
joueur est interrompu en l'air, le recast disparaît.

**A --- Chambre à vide**

**Tags :** Zone, Anti-projectile, Gestion de souffle

**Activation et fonctionnement :** Une sphère de basse pression
apparaît. Les projectiles qui y entrent ralentissent fortement ; les
sauts et impulsions aériennes y perdent de la hauteur.

**Mécanique réelle :** Les personnages peuvent combattre normalement au
sol, mais les longues canalisations respiratoires ou souffles continus
sont écourtés. Le Fûton n'est pas immunisé à ses propres contraintes, il
les maîtrise simplement mieux grâce à ses Courants.

**Synergies / intérêt :** Excellent outil de contrôle contre les
compositions projectile et de préparation pour Fil du vide.

**Contre-jeu :** Zone fixe, aucun hard-CC et dégâts quasi nuls. Les
combattants de mêlée au sol peuvent l'ignorer en grande partie.

**S --- Typhon des huit directions**

**Tags :** Domaine vectoriel, Recast, Contrôle

**Activation et fonctionnement :** Huit points de vent apparaissent
autour d'une grande zone. À chaque impulsion, quatre d'entre eux
soufflent vers le centre et quatre vers l'extérieur.

**Mécanique réelle :** Le lanceur peut réactiver pour faire tourner le
motif de 45 degrés, changeant instantanément les corridors sûrs. Les
personnages ne sont jamais hard-stun : ils doivent corriger leur
trajectoire.

**Synergies / intérêt :** Ultime de contrôle spatial très skillé, qui
transforme les déplacements et peut aligner plusieurs ennemis pour une
coupe.

**Contre-jeu :** Motifs visibles au sol et rythme constant. Un joueur
calme peut apprendre le cycle et se placer entre les flux.

**S --- Lame atmosphérique**

**Tags :** Grande coupe, Télégraphe, Corridor

**Activation et fonctionnement :** Le lanceur condense une immense lame
invisible révélée par une distorsion de l'air. Après une longue
préparation, elle traverse la carte en ligne droite sur une grande
distance.

**Mécanique réelle :** Après le passage, un Corridor de basse pression
reste brièvement : tous les déplacements dans le sens de la lame sont
accélérés, ceux à contre-sens ralentis. Le sort crée donc une
conséquence tactique même s'il manque.

**Synergies / intérêt :** Peut servir de finisher, ouvrir une route
d'engage ou couper une retraite. Les autres techniques Fûton exploitent
ensuite le corridor.

**Contre-jeu :** Télégraphe très long, direction verrouillée tôt et
possibilité claire de sortir de l'axe. Le burst ne doit jamais être
garanti par un simple lock-on.

# 5. Clans --- 100 techniques

## Konoha

### Senju

**Identité :** Le kit Senju tourne autour de la Vigueur : encaisser,
rester actif et transformer la pression reçue en ressources. Il mélange
robustesse, contrôle du terrain et poussées de puissance. Cette version
assume une expression végétale du chakra à haut rang ; si le lore du
serveur réserve strictement le Mokuton, les visuels peuvent être
remplacés par des manifestations de chakra vital sans changer les
mécaniques.

**Mécanique signature :** Vigueur : le Senju gagne jusqu'à 3 charges en
infligeant ou recevant des dégâts significatifs, avec un délai interne.
Plusieurs techniques peuvent consommer 1 à 3 Vigueurs pour obtenir une
variante renforcée. La Vigueur expire hors combat.

**D --- Impulsion ancestrale**

**Tags :** Self-buff, Ressource, Anti-slow

**Activation et fonctionnement :** Le Senju concentre son chakra dans
tout le corps. Il supprime les ralentissements légers, gagne brièvement
de la ténacité aux déplacements forcés et reçoit 1 Vigueur si l'effet
retire réellement un contrôle.

**Mécanique réelle :** La technique n'est pas un cleanse universel :
elle ne retire ni stun dur ni sceau. Si lancée sans debuff, elle donne
seulement une courte accélération.

**Synergies / intérêt :** Permet d'entrer dans le cycle de Vigueur et de
convertir une mauvaise situation en reprise de tempo.

**Contre-jeu :** Le bonus est court et la technique gaspillée à vide
offre peu. Les ennemis peuvent attendre sa fin avant d'engager leurs
vrais contrôles.

**C --- Poigne de sève**

**Tags :** Mêlée, Vol de tempo, Sustain

**Activation et fonctionnement :** Un coup de paume lourd marque la
cible d'un Sceau de sève pendant quelques secondes. Chaque fois que
cette cible inflige des dégâts au Senju, une petite portion est
convertie en Vigueur potentielle ; au troisième déclenchement, le sceau
se rompt et rend une petite quantité de vie.

**Mécanique réelle :** Consommer 1 Vigueur à l'impact transforme le coup
en saisie courte qui stoppe l'élan de la cible sans l'immobiliser
longtemps.

**Synergies / intérêt :** Crée un duel où frapper le Senju alimente sa
résistance, mais où ignorer le sceau laisse au Senju l'initiative.

**Contre-jeu :** Portée de mêlée et marque visible. L'adversaire peut
temporiser jusqu'à expiration ou changer de cible.

**B --- Rempart de racines**

**Tags :** Mur, Cover, Ressource

**Activation et fonctionnement :** Le Senju fait surgir un rempart
courbe. Sans Vigueur, il s'agit d'un couvert destructible. En consommant
1/2/3 charges, le mur gagne respectivement plus de largeur, une
excroissance latérale, puis une brève repousse si un ennemi se trouve
exactement sur la zone d'apparition.

**Mécanique réelle :** Le rempart ne peut pas fermer totalement une
porte ou emprisonner un joueur. Sa forme favorise les angles plutôt que
le blocage brut.

**Synergies / intérêt :** Sert à protéger, couper une ligne de tir et
créer un terrain favorable à Floraison de combat.

**Contre-jeu :** Télégraphe au sol, structure destructible, coût de
ressource important si l'on veut la version complète.

**A --- Floraison de combat**

**Tags :** Zone hybride, Sustain, Root conditionnel

**Activation et fonctionnement :** Le Senju plante un noyau vital qui
fait pousser plusieurs veines au sol. Les alliés qui restent près d'une
veine reçoivent de petites pulsations de récupération ; les ennemis qui
traversent deux veines différentes en peu de temps sont brièvement
Enracinés.

**Mécanique réelle :** Le noyau consomme automatiquement 1 Vigueur si
disponible pour étendre une veine supplémentaire vers la direction du
viseur.

**Synergies / intérêt :** Le sort récompense le placement et les
déplacements forcés : on peut pousser une cible à travers une seconde
veine plutôt que compter sur une immobilisation gratuite.

**Contre-jeu :** Noyau destructible, soins modestes et racine
entièrement évitable si l'adversaire ne retraverse pas plusieurs veines.

**S --- Avatar du grand bois**

**Tags :** Transformation, Armure, Recast

**Activation et fonctionnement :** Le Senju dépense toute sa Vigueur
pour former une armure végétale massive autour de lui. Chaque charge
consommée ajoute un segment d'armure. Tant que des segments restent, ses
attaques de mêlée gagnent de la portée et la première attaque reçue de
chaque direction brise un segment au lieu de provoquer tout son
déplacement forcé.

**Mécanique réelle :** Réactiver sacrifie les segments restants pour
envoyer des bras-racines dans les directions correspondantes, créant un
finisher de zone dont la taille dépend de ce qui n'a pas été détruit.

**Synergies / intérêt :** Ultime à double usage : survivre à un focus ou
conserver l'armure pour menacer un relâchement massif.

**Contre-jeu :** Transformation lente, très visible, pas d'immunité aux
dégâts continus. Les adversaires peuvent user les segments avant
d'engager fort.

### Uchiha

**Identité :** Le kit Uchiha est fondé sur la Lecture. Le Sharingan ne
donne pas une esquive automatique permanente : il récompense
l'observation d'une cible, la mémorisation de ses actions et les
réponses parfaitement timées. Le clan excelle dans le duel mental, les
feintes et le contre.

**Mécanique signature :** Lecture : garder une cible dans son champ de
vision pendant qu'elle attaque génère jusqu'à 3 Lectures sur elle. Les
Lectures sont propres à chaque cible et disparaissent si elle reste hors
vision trop longtemps. Les techniques Uchiha consomment ces informations
pour améliorer une réponse, jamais pour auto-gagner le duel.

**D --- Sharingan --- Observation**

**Tags :** Toggle, Information, Ressource

**Activation et fonctionnement :** Le Sharingan s'active à faible coût
continu. Les animations de mudras ennemis proches deviennent légèrement
plus lisibles pour le joueur et observer une attaque complète génère 1
Lecture sur son auteur.

**Mécanique réelle :** Le mode n'affiche pas la future trajectoire, ne
révèle pas l'invisible et ne ralentit pas le temps. Couper le Sharingan
préserve les Lectures déjà gagnées pour quelques secondes.

**Synergies / intérêt :** Base du kit : le joueur doit choisir quand
payer du chakra pour accumuler de l'information.

**Contre-jeu :** Drain continu et nécessité de réellement regarder la
cible. Les attaques hors écran, pièges au sol et feintes réduisent son
avantage.

**C --- Genjutsu --- Faux pas**

**Tags :** Illusion, Decoy, Mindgame

**Activation et fonctionnement :** L'Uchiha consomme 1 Lecture sur une
cible visible pour créer, uniquement pour elle, une fausse image de
l'Uchiha qui effectue un dash dans une direction choisie. Le vrai
personnage reste visible mais pendant une fraction de seconde les deux
silhouettes sont visuellement équivalentes.

**Mécanique réelle :** Si la cible frappe l'illusion, celle-ci éclate et
applique un bref Flou de visée : son prochain lock-on ne s'accroche pas
automatiquement.

**Synergies / intérêt :** Le sort ne contrôle pas les inputs ; il crée
une vraie fausse information que le joueur peut lire ou ignorer.

**Contre-jeu :** Un adversaire qui suit les sons, les effets au sol ou
attend la fin de l'illusion ne subit presque rien. Une seule cible voit
le faux.

**B --- Mimétisme analytique**

**Tags :** Copie limitée, Adaptation, Recast

**Activation et fonctionnement :** Après avoir observé jusqu'au bout une
technique de nature de rang B ou inférieur, l'Uchiha peut consommer 2
Lectures de son lanceur pour enregistrer son profil pendant quelques
secondes. Un recast lance une version mimétique simplifiée.

**Mécanique réelle :** La copie reproduit uniquement la géométrie
principale --- projectile, cône, dash ou zone --- avec des dégâts
neutres réduits. Elle ne copie ni ressources propres, ni invocations, ni
passifs, ni effets de clan.

**Synergies / intérêt :** Mécanique extrêmement flexible qui récompense
la connaissance des kits adverses sans voler leurs identités.

**Contre-jeu :** Il faut voir le cast complet, disposer de Lectures et
utiliser la copie rapidement. Les techniques incompatibles donnent
simplement un bonus de Lecture au lieu d'être copiées.

**A --- Sharingan --- Prédiction**

**Tags :** Parade avancée, Reposition, Duel

**Activation et fonctionnement :** L'Uchiha cible un adversaire
possédant au moins 2 Lectures et entre dans une fenêtre de prédiction
très courte. Si cette cible le touche directement pendant la fenêtre,
l'Uchiha consomme 2 Lectures, réduit fortement l'impact et effectue
automatiquement un pas latéral choisi au dernier instant par le joueur.

**Mécanique réelle :** La parade ne déclenche pas sur les dégâts de zone
déjà posés. Si elle réussit, le prochain coup de l'Uchiha contre cette
cible gagne un léger bonus de portée, pas de dégâts garantis.

**Synergies / intérêt :** Crée un échange lisible de type "je sais ce
que tu vas faire", sans invulnérabilité gratuite.

**Contre-jeu :** Fenêtre très courte et ciblée sur une seule personne.
Une feinte ou une attaque d'un allié la fait échouer.

**S --- Susanoo --- Gardien incomplet**

**Tags :** Avatar défensif, Arc de garde, Recast

**Activation et fonctionnement :** Un squelette spectral enveloppe
partiellement l'Uchiha. Il possède une jauge d'intégrité séparée et
protège surtout l'arc frontal. Les attaques qui frappent le dos touchent
normalement le joueur.

**Mécanique réelle :** Chaque Lecture encore présente sur les ennemis
proches permet au Susanoo de générer une flèche spectrale à usage
unique. Le joueur peut réactiver pour tirer toutes les flèches
successivement vers les cibles correspondantes, puis le Susanoo se
dissipe.

**Synergies / intérêt :** L'ultime convertit l'information accumulée
pendant le combat en puissance défensive puis offensive.

**Contre-jeu :** Très visible, mobilité réduite, angles morts réels et
jauge destructible. Briser la ligne de vue avant les flèches annule leur
guidage.

### Uzumaki

**Identité :** Les Uzumaki utilisent le fuinjutsu comme une grammaire de
combat. Ils posent des Glyphes puis les relient, inversent ou
déclenchent. Leur force vient de la préparation d'un espace et de la
capacité à modifier les règles d'un affrontement pendant quelques
secondes.

**Mécanique signature :** Glyphes : le joueur peut maintenir jusqu'à 4
Glyphes actifs sur le sol, un ennemi ou un allié. Les techniques
suivantes peuvent consommer ou relier ces Glyphes. Un Glyphe est visible
et peut être détruit s'il est posé sur le terrain.

**D --- Fuda d'entrave**

**Tags :** Tag, Debuff conditionnel, Setup

**Activation et fonctionnement :** Un petit sceau est lancé comme un
projectile court. Sur ennemi, il devient un Glyphe d'entrave : le
premier dash ou déplacement instantané utilisé avant expiration est
raccourci et détruit le sceau. Sur le sol, il devient simplement un
Glyphe neutre.

**Mécanique réelle :** Le sceau n'empêche jamais l'utilisation de la
mobilité ; il en réduit seulement la distance une fois.

**Synergies / intérêt :** Prépare les chaînes et barrières tout en
créant une réponse légère aux personnages très mobiles.

**Contre-jeu :** Projectile esquivable et sceau clairement visible. Une
cible peut volontairement consommer l'effet avec un petit dash.

**C --- Chaîne de scellement**

**Tags :** Tether, Ancre, Recast

**Activation et fonctionnement :** Une chaîne de chakra relie le lanceur
à un Glyphe ou à une cible marquée. Tant que la portée n'est pas
dépassée, le joueur peut réactiver pour tirer légèrement le point le
plus léger vers le plus lourd.

**Mécanique réelle :** Sur un Glyphe de terrain, cela fonctionne comme
un grappin. Sur un ennemi, le déplacement est partagé entre les deux
combattants plutôt qu'un pull unilatéral.

**Synergies / intérêt :** Permet des repositionnements créatifs et donne
de la valeur à chaque Glyphe déjà placé.

**Contre-jeu :** Chaîne visible, cassable en dépassant la portée ou en
détruisant le Glyphe. Le recast possède un court délai.

**B --- Barrière quadrillée**

**Tags :** Barrière, Réseau, Anti-projectile

**Activation et fonctionnement :** Le joueur sélectionne jusqu'à trois
Glyphes actifs. Des segments de barrière se forment entre eux pendant
quelques secondes. Les personnages peuvent traverser, mais les
projectiles perdent une partie de leur vitesse et de leur puissance à
chaque segment franchi.

**Mécanique réelle :** Un ennemi portant un Glyphe compte comme un
sommet mobile, créant une barrière dynamique tant que les distances
restent valides.

**Synergies / intérêt :** Peut protéger une équipe, découper un champ de
tir ou transformer un ennemi marqué en élément du propre réseau Uzumaki.

**Contre-jeu :** Les segments sont visibles, n'arrêtent pas la mêlée et
disparaissent si un sommet est détruit ou s'éloigne trop.

**A --- Sceau de renversement**

**Tags :** Contre, Stockage, Redistribution

**Activation et fonctionnement :** L'Uzumaki place un grand Glyphe sur
une zone. La première technique hostile de zone ou projectile lourd qui
le frappe est partiellement absorbée et stockée sous forme d'Écho.

**Mécanique réelle :** Le joueur peut ensuite placer un Glyphe d'Écho
ailleurs : il ne recrée pas le jutsu original, mais libère une onde
neutre de même catégorie --- explosion, ligne ou cône --- avec puissance
plafonnée.

**Synergies / intérêt :** Le kit gagne une défense active qui transforme
l'agression adverse en ressource de placement.

**Contre-jeu :** Un seul Écho à la fois, fenêtre d'absorption claire,
ultimes non stockables et Glyphe destructible.

**S --- Chaînes adamantines --- Prison des huit sceaux**

**Tags :** Réseau, Capture progressive, Objectif

**Activation et fonctionnement :** Huit pointes de chakra apparaissent
autour d'une large zone et projettent des chaînes entre les Glyphes
existants. Chaque fois qu'un ennemi traverse une chaîne, il accumule 1
Verrou. À 3 Verrous, il est brièvement immobilisé et tous ses Verrous
sont retirés.

**Mécanique réelle :** Les chaînes ne bloquent jamais physiquement. Les
alliés peuvent détruire les pointes extérieures pour ouvrir le réseau.
Les Glyphes déjà préparés changent la forme de la prison.

**Synergies / intérêt :** Ultime de contrôle construit : un bon Uzumaki
prépare ses Glyphes avant l'activation et force plusieurs mauvaises
trajectoires.

**Contre-jeu :** Sans préparation, le réseau est plus simple. Les
pointes ont des PV et les Verrous expirent en sortant de la zone.

### Nara

**Identité :** Le Nara transforme les ombres en réseau de lignes et
d'ancres. Son kit ne repose pas sur un unique hard-CC : il prépare des
connexions, punit les trajectoires et peut brièvement imposer une
symétrie de mouvement à une cible.

**Mécanique signature :** Ancres d'ombre : certaines techniques posent
des points d'ombre sur le terrain. Une ligne d'ombre peut relier le Nara
à une Ancre ou à un ennemi. Les obstacles coupent physiquement les
lignes. La longueur disponible est limitée et constitue la ressource
principale du kit.

**D --- Fil d'ombre**

**Tags :** Skillshot au sol, Tether, Setup

**Activation et fonctionnement :** Une ombre fine file sur le sol en
ligne droite. Si elle touche un ennemi, elle crée un lien pendant
quelques secondes ; si elle atteint un mur ou s'arrête au maximum de
portée, elle crée une Ancre.

**Mécanique réelle :** Le lien ne contrôle pas encore la cible mais
révèle sa direction de déplacement et compte comme connexion pour les
techniques suivantes.

**Synergies / intérêt :** Outil de base du réseau Nara, utile même
lorsqu'il manque la cible grâce à l'Ancre créée.

**Contre-jeu :** La ligne doit rester sur une surface continue et ne
saute pas les fossés. Briser la ligne de vue avec un obstacle coupe le
lien.

**C --- Pas jumeau**

**Tags :** Mimétisme partiel, Recast, Duel

**Activation et fonctionnement :** Sur une cible reliée, le Nara active
un mimétisme pendant une courte fenêtre. Chaque fois qu'il effectue un
déplacement latéral brusque, la cible reçoit une impulsion faible dans
la direction miroir.

**Mécanique réelle :** La technique n'imite ni attaques ni dashes
complets. Le joueur peut réactiver pour rompre le lien et récupérer une
petite portion de longueur d'ombre.

**Synergies / intérêt :** Permet de dérégler le spacing adverse et de
pousser subtilement vers une Ancre ou une zone alliée.

**Contre-jeu :** Effet faible individuellement, lien visible et
cassable. Les mouvements verticaux ou immobilité neutralisent presque
tout.

**B --- Couture des ombres**

**Tags :** Piège entre ancres, Root conditionnel

**Activation et fonctionnement :** Le Nara choisit deux Ancres ;
plusieurs aiguilles d'ombre remontent périodiquement le long du segment.
Un ennemi qui traverse le segment au moment d'une pulsation est
brièvement cloué au sol.

**Mécanique réelle :** Chaque déclenchement consomme une partie de la
longueur maximale du réseau, empêchant le spam infini.

**Synergies / intérêt :** Transforme les Ancres D en véritables pièges
et récompense la construction d'angles.

**Contre-jeu :** Pulsations rythmiques visibles et segment fixe.
Détruire ou contourner une Ancre annule le piège.

**A --- Possession tactique**

**Tags :** Contrôle limité, Symétrie, Canalisation

**Activation et fonctionnement :** Sur une cible reliée avec
suffisamment de longueur disponible, le Nara canalise et impose pendant
quelques secondes une symétrie de déplacement : marcher en avant la fait
marcher légèrement vers le Nara, marcher à gauche la pousse à droite,
etc.

**Mécanique réelle :** La cible garde ses attaques, sa caméra et ses
dashes. Les dashes rompent une partie de l'effet au prix d'un
ralentissement bref après l'arrivée.

**Synergies / intérêt :** C'est un contrôle de haute compétence qui
perturbe sans retirer totalement les commandes. Idéal pour forcer une
mauvaise orientation.

**Contre-jeu :** Canalisation interruptible, portée stricte, coût élevé
en longueur d'ombre et cible toujours capable de riposter.

**S --- Crépuscule des cent ombres**

**Tags :** Domaine, Réseau automatique, Gestion de ressource

**Activation et fonctionnement :** Le Nara étend temporairement sa
réserve d'ombre sur une large zone. Toutes ses Ancres se relient entre
elles si aucun obstacle ne coupe le segment, formant un maillage.

**Mécanique réelle :** Le joueur peut déplacer son point d'origine d'une
Ancre à l'autre. Les ennemis qui traversent trop de segments en peu de
temps gagnent des Charges d'Ombre ; à 3, leur prochain dash est annulé
au départ et les charges disparaissent.

**Synergies / intérêt :** Ultime de contrôle de trajectoire qui
récompense énormément la préparation de terrain, sans immobiliser en
permanence.

**Contre-jeu :** Le maillage est entièrement visible. Les ennemis
peuvent détruire les Ancres ou rester dans une même cellule pour éviter
d'accumuler des Charges.

### Akimichi

**Identité :** Le clan Akimichi gère une réserve de Calories transformée
en masse, vitesse ou puissance. Le kit alterne entre dépenses explosives
et récupération. Ses techniques changent réellement le volume du
personnage et donc sa collision, ce qui impose de gérer l'espace avec
précision.

**Mécanique signature :** Calories : jauge dédiée remplie
progressivement hors des grosses dépenses et par certaines actions. Les
techniques consomment des quantités différentes. À Calories basses, le
personnage n'est pas affaibli en permanence, mais ses techniques
avancées perdent certaines variantes.

**D --- Poing d'expansion**

**Tags :** Mêlée extensible, Sweet spot, Ressource

**Activation et fonctionnement :** Le bras grossit et s'allonge
brutalement. L'extrémité du poing possède la meilleure zone d'impact ;
toucher trop près inflige moins de recul.

**Mécanique réelle :** Une petite quantité de Calories peut être
consommée pour prolonger légèrement la portée au dernier moment, créant
un mindgame de distance.

**Synergies / intérêt :** Outil de poke Akimichi inhabituel qui prépare
les collisions de plus gros volume.

**Contre-jeu :** Animation lente et bras vulnérable visuellement ; rater
au maximum de portée laisse une récupération notable.

**C --- Corps-bélier**

**Tags :** Charge, Armor, Collision

**Activation et fonctionnement :** Le torse et les épaules grossissent
pendant une charge courte. Le premier contrôle léger reçu est ignoré,
mais les dégâts restent normaux. Le premier ennemi percuté est poussé
avec le joueur jusqu'à la fin de la charge.

**Mécanique réelle :** Percuter un mur ou une structure termine la
charge et provoque un impact plus fort, sans stun prolongé.

**Synergies / intérêt :** Excellent pour déplacer une cible vers un
allié ou sortir quelqu'un d'un objectif.

**Contre-jeu :** Direction peu flexible et volume augmenté : les
skillshots ennemis deviennent plus faciles à toucher.

**B --- Boulet humain**

**Tags :** Mode déplacement, Inertie, Recast

**Activation et fonctionnement :** Le personnage se met en boule et
roule. Il accélère progressivement, tourne avec inertie et rebondit
légèrement sur certains obstacles au lieu de s'arrêter.

**Mécanique réelle :** Chaque ennemi ne peut être frappé qu'une fois par
roulade. Un recast termine le mode par un freinage circulaire qui
repousse autour du point d'arrêt.

**Synergies / intérêt :** Crée une vraie mécanique de conduite, de
trajectoire et de rebond plutôt qu'un simple dash.

**Contre-jeu :** Difficile à tourner, caméra et anticipation
nécessaires. Les obstacles lourds, fosses et contrôles forts arrêtent la
roulade.

**A --- Mode papillon**

**Tags :** Transformation, Conversion HP/Calories, Tempo

**Activation et fonctionnement :** Le chakra forme des ailes. Pendant
quelques secondes, les Calories se drainent en continu pour augmenter
vitesse d'attaque, accélération et puissance des impacts.

**Mécanique réelle :** À Calories nulles, le mode peut continuer en
consommant progressivement des PV, mais le joueur peut le couper à tout
moment. Les techniques Akimichi voient leurs collisions légèrement
agrandies pendant le mode.

**Synergies / intérêt :** Pic de puissance flexible : le joueur décide
jusqu'où pousser la ressource, voire sacrifier de la vie pour finir un
combat.

**Contre-jeu :** Drain très visible, aucune immunité défensive et
punition sévère si le joueur prolonge trop.

**S --- Expansion colossale --- Chute du titan**

**Tags :** Giant form, Zone, Terrain, Finisher

**Activation et fonctionnement :** L'Akimichi devient gigantesque
pendant une courte durée et choisit un point d'impact. Il peut marcher
lentement vers la zone puis s'abattre en consommant toutes ses Calories
restantes.

**Mécanique réelle :** La taille de l'onde dépend des Calories, tandis
que les dégâts centraux sont plafonnés. Les personnages proches du bord
sont surtout repoussés ; le centre inflige un lourd impact.

**Synergies / intérêt :** Ultime d'espace et de menace : on peut
l'utiliser pour couper une zone, pas seulement pour tuer.

**Contre-jeu :** Transformation lente et centre d'impact annoncé
longtemps à l'avance. Plus le joueur attend pour se placer, plus il
donne de temps aux adversaires pour sortir.

## Suna

### Roran

**Identité :** Le clan Roran se joue comme un maître d'éventail et de
rythme. Contrairement au Fûton pur, il ne crée pas principalement des
lames de vent : il alterne des Postures d'éventail qui changent la
fonction de ses attaques, accumule des Battements et utilise ces
Battements pour rediriger, repousser ou accélérer. C'est un kit de tempo
et de lecture.

**Mécanique signature :** Battements : les techniques Roran génèrent
jusqu'à 3 Battements. Le joueur peut les dépenser pour renforcer un
prochain mouvement d'éventail. Certaines techniques changent selon la
Posture actuelle : Ouverte favorise le contrôle de zone ; Fermée
favorise la précision et la mobilité. Changer de posture est intégré aux
casts, pas un bouton séparé permanent.

**D --- Claque d'éventail**

**Tags :** Parade légère, Génération, Direction

**Activation et fonctionnement :** Un coup d'éventail très court balaie
devant le joueur. Il repousse légèrement les ennemis et dévie les petits
projectiles sur le côté au lieu de les annuler.

**Mécanique réelle :** Réussir une déviation génère 1 Battement. Toucher
un ennemi au centre génère aussi 1 Battement, avec délai interne.

**Synergies / intérêt :** Technique de base servant à construire la
ressource et à contrôler le spacing sans dégâts excessifs.

**Contre-jeu :** Portée très courte et fenêtre de déviation brève. Les
rayons, AOE et attaques lourdes traversent normalement.

**C --- Trois souffles cadencés**

**Tags :** Séquence, Choix de rythme, Recast

**Activation et fonctionnement :** Le Roran effectue jusqu'à trois
balayages. Le premier est large et faible, le second plus étroit, le
troisième très fin et puissant. Le joueur choisit le tempo entre les
coups avec le recast.

**Mécanique réelle :** Dépenser 1 Battement sur un coup le rend
instantanément disponible et modifie sa fonction : large = plus de push,
moyen = ralentissement bref, fin = petite perforation de garde.

**Synergies / intérêt :** Le joueur peut s'arrêter après un ou deux
souffles pour garder du tempo, ou engager toute la séquence pour une
vraie menace.

**Contre-jeu :** Chaque souffle est télégraphié et la séquence peut être
interrompue. Brûler ses Battements trop tôt rend la fin prévisible.

**B --- Éventail miroir**

**Tags :** Contre directionnel, Redirection, Ressource

**Activation et fonctionnement :** Le Roran ouvre complètement son
éventail pendant une très courte fenêtre. Un projectile compatible ou
une poussée frontale reçue est capté comme Direction.

**Mécanique réelle :** Le prochain mouvement Roran peut consommer cette
Direction pour ajouter le vecteur capturé à son propre effet : un push
reçu de gauche peut ainsi transformer un souffle en diagonale, un
projectile capté peut être relancé comme rafale neutre.

**Synergies / intérêt :** Mécanique de redirection réellement différente
du simple bouclier ; elle récompense l'anticipation et l'angle.

**Contre-jeu :** Une seule Direction stockée, durée courte, aucun effet
contre mêlée lourde ou zone. Le joueur doit ensuite réussir à exploiter
le vecteur.

**A --- Danse des quatre rafales**

**Tags :** Mobilité séquencée, Courants, Combo

**Activation et fonctionnement :** Le Roran effectue quatre pas glissés
autour d'une zone centrale, chacun accompagné d'un coup d'éventail
orienté vers le centre ou vers l'extérieur selon l'input.

**Mécanique réelle :** Chaque Battement consommé permet de remplacer un
pas par un mini-dash traversant la zone. Les quatre coups laissent des
couloirs d'air qui persistent brièvement et accélèrent le Roran s'il les
recroise.

**Synergies / intérêt :** Crée une chorégraphie de duel où le joueur
construit ses propres rails de déplacement.

**Contre-jeu :** Trajectoires en arcs lisibles et pas d'invulnérabilité.
Les contrôles de zone au centre punissent un Roran trop prévisible.

**S --- Théâtre des mille vents**

**Tags :** Domaine, Stances, Commandes séquencées

**Activation et fonctionnement :** Le Roran plante son grand éventail et
crée un domaine circulaire où quatre directions de vent sont
matérialisées. À intervalles courts, il peut choisir l'une d'elles et
déclencher soit une poussée, soit une aspiration selon sa Posture.

**Mécanique réelle :** Chaque Battement disponible au lancement ajoute
une commande gratuite supplémentaire. Les ennemis voient la direction
choisie une fraction de seconde avant l'impulsion.

**Synergies / intérêt :** Ultime de chef d'orchestre : contrôle du
spacing, protection d'alliés, mise en ligne pour des skillshots, sans
hard-stun automatique.

**Contre-jeu :** Domaine fixe, éventail central destructible et
télégraphes visibles. Une équipe qui se disperse réduit la valeur des
impulsions.

### Sabaku

**Identité :** Le clan Sabaku commande une masse de sable autonome qui
agit comme une extension du personnage. Le sable n'est pas du Doton
classique : il peut rester en suspension, intercepter, poursuivre et
construire des volumes mobiles. Le joueur gère une Réserve de sable qui
circule entre défense et attaque.

**Mécanique signature :** Réserve de sable : jauge représentant la
quantité actuellement disponible autour du joueur. Créer une défense
immobilise temporairement du sable ; lancer une grosse attaque en
dépense. Le sable revient progressivement au joueur ou plus vite si une
structure est rappelée.

**D --- Sable gardien**

**Tags :** Interception automatique limitée, Ressource, Recast

**Activation et fonctionnement :** Une petite masse de sable flotte
autour du Sabaku. Le premier projectile léger venant d'un arc frontal
est automatiquement bloqué en consommant une portion de Réserve.

**Mécanique réelle :** Le joueur peut réactiver pour envoyer
immédiatement le sable restant comme petite gifle directionnelle,
sacrifiant la défense. L'auto-interception possède un délai interne
clair.

**Synergies / intérêt :** Introduit le principe fondamental : le même
sable ne peut pas défendre et attaquer simultanément.

**Contre-jeu :** Arc frontal seulement, attaques lourdes traversantes et
Réserve visible. Après une interception, une vraie fenêtre vulnérable
existe.

**C --- Main des dunes**

**Tags :** Bras dirigé, Grab conditionnel, Reposition

**Activation et fonctionnement :** Une main de sable se forme au sol et
avance vers le point visé. Elle peut contourner légèrement un obstacle
bas. Au contact, elle serre la cible et la tire d'une courte distance
avant de se désagréger.

**Mécanique réelle :** Une cible touchée auparavant par du sable porte
du Grain marqué ; contre elle, la main se forme plus vite mais ne tire
pas plus fort.

**Synergies / intérêt :** Outil de déplacement précis, utile pour sortir
quelqu'un d'un couvert ou le rapprocher d'une zone.

**Contre-jeu :** Main visible au sol, destructible avant fermeture et
traction courte. Un dash au bon moment la fait rater.

**B --- Cercueil de sable**

**Tags :** Capture progressive, Ressource engagée, Exécution
conditionnelle

**Activation et fonctionnement :** Le Sabaku envoie une grande portion
de sa Réserve autour d'une cible. Pendant une courte fenêtre, le sable
se referme progressivement ; si la cible reste dans la zone, elle est
emprisonnée brièvement dans un cocon destructible.

**Mécanique réelle :** Le Sabaku doit maintenir une partie de sa Réserve
engagée tant que le cocon existe. Réactiver écrase le cocon pour
infliger un burst modéré et le détruire immédiatement ; attendre permet
surtout de contrôler.

**Synergies / intérêt :** Choix intéressant entre contrôle d'équipe et
dégâts. Main des dunes aide à empêcher la sortie pendant la fermeture.

**Contre-jeu :** Pré-zone visible, possibilité de dash avant fermeture,
cocon attaquable par les alliés et perte massive de Réserve pendant son
maintien.

**A --- Mer de sable mouvante**

**Tags :** Terrain mobile, Ressource, Surf

**Activation et fonctionnement :** Le Sabaku répand une large couche de
sable dans une zone. La surface se déplace lentement dans une direction
choisie et entraîne légèrement les personnages avec elle.

**Mécanique réelle :** Le lanceur peut surfer rapidement sur sa propre
mer et rappeler une partie du sable derrière lui, réduisant la zone mais
régénérant sa Réserve. Les ennemis qui sprintent à contre-courant
laissent un Grain marqué.

**Synergies / intérêt :** Contrôle de terrain dynamique, différent d'une
simple zone de slow. Sert à déplacer un combat entier et recharger
tactiquement le kit.

**Contre-jeu :** Coût initial élevé, zone lente et aucune
immobilisation. Quitter les bords latéraux reste possible.

**S --- Mausolée du désert**

**Tags :** Construction massive, Multi-capture, Gestion ressource

**Activation et fonctionnement :** Toute la Réserve disponible se
fragmente en quatre piliers de sable autour d'une zone. Le joueur peut
commander successivement chaque pilier pour balayer vers le centre,
créant quatre fenêtres de compression.

**Mécanique réelle :** Une cible frappée par deux balayages différents
reçoit un Sceau d'ensevelissement ; au troisième, elle est brièvement
enfermée dans un sarcophage individuel. Les piliers dépensés
disparaissent et rendent progressivement leur sable.

**Synergies / intérêt :** Ultime où la maîtrise des timings et des
angles compte davantage que les dégâts bruts.

**Contre-jeu :** Les balayages sont séquentiels, visibles et évitables.
Consommer toute la Réserve laisse le Sabaku presque sans défense après
l'ultime.

### Hôki

**Identité :** Hôki est un clan de chercheurs et d'altération
corporelle. Il ne repose pas sur un seul poison : il prépare des
Réactifs, analyse une cible puis adapte ses techniques. Le joueur
choisit constamment entre booster son propre organisme et contaminer
l'adversaire.

**Mécanique signature :** Réactifs : trois catégories existent ---
Stimulant, Coagulant, Neurotoxique. Une seule Préparation peut être
active dans le corps du Hôki à la fois. Plusieurs techniques changent
d'effet selon cette Préparation. Les toxines ennemies accumulent une
Saturation mais possèdent des plafonds stricts.

**D --- Injection expérimentale**

**Tags :** Self-buff, Choix modal, Ressource

**Activation et fonctionnement :** Le Hôki sélectionne rapidement un
Réactif et se l'injecte. Stimulant augmente brièvement l'accélération ;
Coagulant réduit le prochain saignement ou DOT reçu ; Neurotoxique rend
le prochain projectile Hôki plus perturbant.

**Mécanique réelle :** Changer de Préparation avant sa fin remplace
l'ancienne sans cumuler les bonus.

**Synergies / intérêt :** Le sort définit le contexte des quatre
techniques suivantes et donne au joueur un mini-loadout en combat.

**Contre-jeu :** Animation d'injection interruptible si réalisée sous
pression ; les bonus restent courts et spécialisés.

**C --- Aiguille adaptative**

**Tags :** Projectile, Debuff variable, Analyse

**Activation et fonctionnement :** Une aiguille rapide applique un effet
selon la Préparation : Stimulant provoque une brève accélération
involontaire vers l'avant ; Coagulant alourdit la régénération de
ressources ; Neurotoxique augmente la Saturation et brouille légèrement
les indicateurs de cast.

**Mécanique réelle :** Toucher une cible révèle pendant quelques
secondes quelle catégorie de résistance elle possède le mieux,
information seulement visible au Hôki.

**Synergies / intérêt :** Permet de tester une cible et d'adapter les
prochains Réactifs.

**Contre-jeu :** Projectile fin, effets modestes et jamais de contrôle
complet. Purge ou attente courte suffisent.

**B --- Greffe réactive**

**Tags :** Mutation temporaire, Réponse aux dégâts, Modal

**Activation et fonctionnement :** Le Hôki transforme momentanément une
partie de son corps. Stimulant donne des tendons renforcés : premier
knockback réduit. Coagulant crée une carapace qui absorbe un impact.
Neurotoxique fait suinter une brume courte lorsqu'il est frappé en
mêlée.

**Mécanique réelle :** Chaque variante possède une seule charge et
disparaît après déclenchement.

**Synergies / intérêt :** Défense contextuelle exigeant de prédire le
type d'engage adverse plutôt qu'un bouclier universel.

**Contre-jeu :** Mauvais Réactif = très faible valeur. L'adversaire peut
reconnaître visuellement la mutation et changer son plan.

**A --- Dissection de combat**

**Tags :** Mark, Analyse avancée, Exécution conditionnelle

**Activation et fonctionnement :** Après une courte canalisation sur une
cible visible, le Hôki crée un Profil biologique. Pendant quelques
secondes, ses attaques révèlent une jauge de Saturation spécifique à
cette cible et gagnent un effet selon son comportement récent :
mobilité, défense ou spam de jutsu.

**Mécanique réelle :** Atteindre le seuil de Saturation ne stun pas :
cela déclenche une Crise adaptée --- perte d'accélération, fragilité de
garde ou hausse temporaire des coûts de chakra.

**Synergies / intérêt :** Technique de chasseur qui récompense
l'observation réelle et le choix de la bonne toxine.

**Contre-jeu :** Canalisation cassée par la ligne de vue et Profil
visible. La cible peut varier son comportement pour empêcher le Hôki
d'exploiter une seule faiblesse.

**S --- Chimère de laboratoire**

**Tags :** Transformation, Adaptation, Choix en temps réel

**Activation et fonctionnement :** Le Hôki ouvre trois emplacements de
Mutation pendant quelques secondes. Chaque fois qu'il subit une
catégorie d'effet significative --- projectile, mêlée, contrôle --- il
peut choisir d'occuper un emplacement avec une adaptation
correspondante.

**Mécanique réelle :** Une adaptation ne donne jamais immunité totale :
elle réduit la répétition de cette catégorie et modifie une attaque Hôki
en réponse. Les trois emplacements imposent donc de décider ce qui
mérite d'être contré.

**Synergies / intérêt :** Ultime extrêmement complexe et réactif, fidèle
à l'identité de chercheur.

**Contre-jeu :** Le mode commence sans bonus, nécessite d'être exposé et
chaque adaptation est visible sur le modèle. Une composition variée
force de vrais choix.

### Kugutsu

**Identité :** Kugutsu est un véritable kit à deux corps. La marionnette
reste physiquement sur le terrain, possède ses propres PV et obéit à des
Commandes. Le joueur doit gérer la distance des fils, l'angle entre lui,
la marionnette et la cible, ainsi que le risque de voir son outil
principal détruit.

**Mécanique signature :** Marionnette : invoquée automatiquement avec le
premier sort, elle reste jusqu'à destruction ou rappel. Les fils ont une
portée maximale. Les Commandes peuvent être lancées depuis le joueur
mais prennent comme origine la marionnette. Détruire la marionnette
impose un délai avant reconstruction.

**D --- Karakuri --- Premier fil**

**Tags :** Summon, Commande, Double origine

**Activation et fonctionnement :** Le Kugutsu déploie sa marionnette à
un point proche. Un appui ultérieur ordonne une frappe simple dans la
direction du viseur depuis la marionnette.

**Mécanique réelle :** Maintenir l'ordre rappelle la marionnette vers le
joueur. Le joueur voit clairement la tension des fils ; dépasser la
portée force automatiquement un rappel partiel.

**Synergies / intérêt :** Fondation du kit : toutes les autres
techniques supposent une vraie position de marionnette.

**Contre-jeu :** La marionnette est destructible, sa frappe de base est
télégraphiée et le maître reste vulnérable lorsqu'il se concentre sur
son placement.

**C --- Croisement des fils**

**Tags :** Swap, Trap de ligne, Mobilité

**Activation et fonctionnement :** Le maître et la marionnette tendent
leurs fils entre eux pendant une courte fenêtre. Les ennemis qui
traversent la ligne sont ralentis et révélés. Le joueur peut réactiver
pour faire glisser simultanément maître et marionnette l'un vers
l'autre, échangeant presque leurs positions.

**Mécanique réelle :** Le mouvement s'arrête si un obstacle bloque l'un
des deux corps.

**Synergies / intérêt :** Outil de repositionnement unique : la ligne
elle-même menace, puis devient axe de swap.

**Contre-jeu :** Prévisible lorsque les deux positions sont connues.
Briser ou contourner la ligne évite toute gêne.

**B --- Arsenal dissimulé**

**Tags :** Mode marionnette, Choix d'arme, Recast

**Activation et fonctionnement :** La marionnette ouvre trois
compartiments. Le joueur choisit au recast : salve de senbon en cône,
câble-grappin étroit ou fumée toxique locale. Après une utilisation, les
autres compartiments se referment jusqu'au prochain cooldown.

**Mécanique réelle :** Chaque option répond à une situation mais aucune
n'est dominante : poke, déplacement ou zoning.

**Synergies / intérêt :** La position préparée de la marionnette permet
des attaques venant d'un angle séparé de celui du maître.

**Contre-jeu :** Une seule option par cast et animation d'ouverture très
lisible. Détruire la marionnette annule l'arsenal.

**A --- Substitution mécanique**

**Tags :** Body swap, Faux corps, Piège

**Activation et fonctionnement :** Le Kugutsu verrouille sa marionnette
puis, pendant une fenêtre courte, peut échanger sa position avec elle
lorsqu'il reçoit une attaque directe. Le corps laissé sur place se
transforme en mannequin explosif après un bref délai.

**Mécanique réelle :** Le swap n'est pas automatique : le joueur doit
confirmer dans la fenêtre. L'explosion inflige surtout un knockback et
marque les cibles pour la prochaine Commande.

**Synergies / intérêt :** Mécanique défensive de haut niveau qui exige
d'avoir bien positionné la marionnette avant le danger.

**Contre-jeu :** Si la marionnette est trop loin, derrière un obstacle
ou détruite, le swap échoue. L'explosion est clairement télégraphiée.

**S --- Cent fils --- Atelier de guerre**

**Tags :** Multi-puppet, Commandes de zone, Gestion

**Activation et fonctionnement :** Le maître déploie temporairement
plusieurs marionnettes mineures autour de sa marionnette principale.
Elles ne sont pas contrôlées individuellement : chaque Commande lancée
par le joueur est reproduite avec un léger décalage par deux copies
situées à des angles différents.

**Mécanique réelle :** Les copies ont un seul point de vie et
disparaissent après avoir reproduit deux Commandes. Le maître doit donc
choisir les ordres importants.

**Synergies / intérêt :** Transforme momentanément chaque technique en
problème géométrique multi-angle sans devenir un auto-aim.

**Contre-jeu :** Les copies sont fragiles, positions visibles et le
maître conserve les mêmes limitations de fils. Une AOE peut nettoyer
rapidement l'atelier.

### Hakumei

**Identité :** Hakumei est un clan d'assassinat et d'illusion. Son
pouvoir central, le Doute, ne retire jamais le contrôle au joueur
adverse : il introduit de fausses informations crédibles ---
silhouettes, sons, marqueurs --- que le Hakumei exploite pour frapper
depuis l'angle inattendu.

**Mécanique signature :** Doute : certaines techniques placent des
charges de Doute sur une cible, maximum 3. Chaque charge permet au
Hakumei de créer une illusion plus convaincante ou d'améliorer une
attaque venant hors du champ de vision. Les charges sont perdues si la
cible frappe correctement le vrai Hakumei ou reste longtemps hors
combat.

**D --- Pas dédoublé**

**Tags :** Dash, Afterimage, Setup

**Activation et fonctionnement :** Le Hakumei effectue un petit dash et
laisse une silhouette poursuivre l'ancienne direction pendant une
seconde. Si la cible ennemie la plus proche tourne sa caméra ou attaque
vers l'afterimage, elle reçoit 1 Doute.

**Mécanique réelle :** L'illusion ne possède pas de collision et
disparaît au premier impact.

**Synergies / intérêt :** Crée du mindgame dès le rang D sans
invisibilité gratuite.

**Contre-jeu :** Les traces au sol, sons et dégâts révèlent toujours le
vrai joueur. Ne pas réagir à l'illusion évite le Doute.

**C --- Kunai du reflet**

**Tags :** Projectile multi-angle, Illusion, Recast

**Activation et fonctionnement :** Le Hakumei lance un vrai kunai et
fait apparaître deux trajectoires illusoires partant de positions
légèrement décalées. Seul un projectile inflige des dégâts.

**Mécanique réelle :** Consommer 1 Doute permet au joueur de choisir
tardivement lequel des trois devient réel, tant qu'aucun n'a encore
touché.

**Synergies / intérêt :** Mécanique de lecture visuelle : l'adversaire
doit observer le geste, l'environnement ou couvrir plusieurs lignes.

**Contre-jeu :** Les faux projectiles traversent les décors de façon
subtilement différente et n'émettent pas le même son à courte portée.

**B --- Marque du doute**

**Tags :** Cible, Faux télégraphes, Pression

**Activation et fonctionnement :** Le Hakumei place une marque sur une
cible déjà affectée par Doute. Pendant quelques secondes, chaque fois
qu'il commence un mudra, la cible voit un second télégraphe plausible
apparaître depuis un autre angle.

**Mécanique réelle :** Le faux télégraphe ne produit jamais de dégâts
mais peut correspondre à un sort réellement disponible, ce qui rend la
lecture difficile. Chaque faux consomme une charge de Doute.

**Synergies / intérêt :** Permet de transformer les ressources
accumulées en pression mentale, surtout avant une vraie attaque à haut
rang.

**Contre-jeu :** Les alliés non marqués voient la réalité et peuvent
communiquer. La marque possède un effet visuel visible au-dessus de la
cible.

**A --- Assassinat de l'angle mort**

**Tags :** Dash ciblé, Condition vision, Finisher

**Activation et fonctionnement :** Le Hakumei choisit une cible marquée
et prépare un dash circulaire autour d'elle. Il ne peut l'exécuter que
si, au moment du recast, il se trouve réellement hors du cône de vision
de la cible.

**Mécanique réelle :** Chaque Doute consommé réduit le bruit du dash et
augmente légèrement la portée ; les dégâts n'augmentent que si le coup
arrive dans le dos, jamais de face.

**Synergies / intérêt :** Le sort récompense le fait d'avoir réellement
trompé l'adversaire, pas simplement d'avoir appuyé sur un bouton de
téléportation.

**Contre-jeu :** Impossible à déclencher sous le regard de la cible.
Tourner rapidement la caméra ou obtenir la vision d'un allié peut
empêcher l'activation.

**S --- Théâtre des morts blancs**

**Tags :** Domaine illusion, Information, Exécution

**Activation et fonctionnement :** Une zone se couvre d'un voile pâle et
plusieurs copies du Hakumei apparaissent, chacune reproduisant ses
déplacements avec un décalage différent. Les copies peuvent simuler des
débuts de mudras mais jamais les impacts réels.

**Mécanique réelle :** Le vrai Hakumei peut échanger une fois sa
position avec une copie en consommant toutes les charges de Doute de sa
cible principale. Après cet échange, toutes les copies se figent une
fraction de seconde, donnant une possibilité de lecture.

**Synergies / intérêt :** Ultime de duel mental spectaculaire, excellent
pour casser le focus et préparer Assassinat.

**Contre-jeu :** Les AOE frappent le vrai comme les copies, les sons
proches restent authentiques et le swap n'est possible qu'une fois.

## Ame

### Chinoike

**Identité :** Le clan Chinoike transforme le sang en information, en
arme et en dette. Son gameplay repose sur l'état Hémorragie et sur des
Liens sanguins temporaires. Il excelle à punir une cible déjà blessée,
mais doit d'abord créer cette condition et s'expose lorsqu'il utilise
son propre sang.

**Mécanique signature :** Dette de sang : infliger ou subir certains
dégâts applique des Gouttes de dette, maximum 3 par cible. Les
techniques Chinoike peuvent les consommer pour augmenter leur contrôle
ou créer un lien. Certaines variantes coûtent une petite portion de PV
au lanceur, jamais létale à elles seules.

**D --- Aiguille carmine**

**Tags :** Projectile, Hémorragie, Ressource

**Activation et fonctionnement :** Le Chinoike crée une aiguille de sang
condensé et la lance rapidement. Elle inflige peu de dégâts, applique
une courte Hémorragie et 1 Goutte de dette.

**Mécanique réelle :** Maintenir légèrement le cast prélève un peu de
vie au lanceur pour rendre l'aiguille perforante sur une seconde cible.

**Synergies / intérêt :** Outil de setup permettant de commencer la
Dette sans dépendre d'une blessure préalable.

**Contre-jeu :** Hitbox fine et coût personnel de la variante
perforante. Une cible peut purger l'Hémorragie ou simplement attendre
son expiration.

**C --- Miroir hématique**

**Tags :** Clone réactif, Contre, Information

**Activation et fonctionnement :** Le lanceur crée une plaque de sang
réfléchissante devant lui. La première attaque directe compatible qui la
touche imprime une silhouette de l'attaquant dans le miroir.

**Mécanique réelle :** Le Chinoike peut réactiver pour faire surgir la
silhouette et reproduire uniquement le déplacement initial de l'attaque
sous forme d'un dash fantôme qui applique 1 Goutte de dette s'il
traverse son auteur.

**Synergies / intérêt :** Ce n'est pas une copie de dégâts : c'est un
outil de contre-position et de lecture.

**Contre-jeu :** Fenêtre courte, miroir directionnel et destructible.
Les AOE ou attaques par derrière l'ignorent.

**B --- Marionnette écarlate**

**Tags :** Tether, Mouvement forcé conditionnel, Ressource

**Activation et fonctionnement :** Sur une cible possédant au moins 2
Gouttes, le Chinoike crée un fil de sang entre elle et lui. Pendant
quelques secondes, chaque gros changement de direction du lanceur tire
légèrement la cible dans le même sens.

**Mécanique réelle :** Consommer la troisième Goutte permet une seule
impulsion plus forte, après quoi le lien se rompt. La cible garde toutes
ses attaques et peut casser la portée.

**Synergies / intérêt :** Contrôle subtil qui devient fort si le
Chinoike sait bouger et combiner avec le terrain.

**Contre-jeu :** Nécessite préparation, ligne visible et portée limitée.
Les dashes permettent souvent de rompre le lien.

**A --- Ketsuryûgan --- Regard de coagulation**

**Tags :** Focus, Debuff adaptatif, Vision

**Activation et fonctionnement :** Le Chinoike fixe une cible pendant
une courte canalisation. S'il maintient le regard, il transforme ses
Gouttes en Coagulation : la cible voit ses prochaines dépenses de chakra
laisser une trace rouge visible et accumule un ralentissement léger de
récupération de chakra.

**Mécanique réelle :** À 3 Gouttes consommées, le prochain gros jutsu de
la cible crée brièvement un point faible hématique visible que le
Chinoike peut frapper pour interrompre sa récupération, pas le cast déjà
lancé.

**Synergies / intérêt :** Crée un duel de ressources et d'information
plutôt qu'un genjutsu de contrôle gratuit.

**Contre-jeu :** Canalisation cassée par la ligne de vue ; l'effet
disparaît avec le temps et ne bloque jamais l'utilisation des
techniques.

**S --- Palais de sang**

**Tags :** Domaine, Ressource partagée, Finisher

**Activation et fonctionnement :** Une grande zone devient un réseau de
filaments rouges. Tout personnage qui perd une quantité significative de
PV dans le domaine laisse une Flaque de sang neutre. Le Chinoike peut
attirer une Flaque vers lui ou vers une cible marquée.

**Mécanique réelle :** Réactiver consomme toutes les Flaques proches
pour créer des pointes depuis leurs positions. Les dégâts dépendent
surtout du nombre d'angles couverts ; une même cible possède un plafond
de hits strict.

**Synergies / intérêt :** Ultime qui transforme le combat entier en
ressource et récompense la préparation de plusieurs blessures.

**Contre-jeu :** Le domaine n'inflige presque rien sans combat actif.
Les Flaques sont visibles et peuvent être évitées ; le Chinoike doit
rester dans la zone pour les commander.

### Fûma

**Identité :** Le clan Fûma est un kit d'armes, de câbles et de
trajectoires. Son arme emblématique n'est pas juste un projectile :
chaque lancer peut créer une Ancre de fil, et le joueur construit
progressivement un réseau pour modifier les rebonds, se déplacer ou
piéger un angle.

**Mécanique signature :** Ancres de fil : jusqu'à 3 ancres peuvent être
actives sur le décor. Les techniques de Fûma peuvent rebondir sur ces
points ou tendre un câble entre eux. Les ancres sont petites mais
visibles et destructibles.

**D --- Shuriken Fûma --- Angle mort**

**Tags :** Boomerang, Ancre, Rebond

**Activation et fonctionnement :** Un grand shuriken est lancé
horizontalement. Sur recast, il plante une lame dans la première surface
proche et crée une Ancre au lieu de revenir. Sans recast, il revient
vers le lanceur.

**Mécanique réelle :** Si le retour passe près d'une Ancre existante, sa
trajectoire se courbe légèrement vers celle-ci avant de revenir.

**Synergies / intérêt :** Dès le premier rang, le joueur choisit entre
dégâts immédiats et préparation du réseau.

**Contre-jeu :** Le projectile est large et visible. Planter l'Ancre
sacrifie le potentiel de double hit.

**C --- Fil du chasseur**

**Tags :** Tripwire, Mobilité, Recast

**Activation et fonctionnement :** Le Fûma relie deux Ancres ou une
Ancre à lui-même par un fil presque invisible à distance mais brillant
de près. Traverser le fil applique un bref ralentissement et révèle la
cible.

**Mécanique réelle :** Le lanceur peut réactiver pour se tirer
rapidement vers l'une des extrémités, rompant le fil.

**Synergies / intérêt :** Le même outil sert de piège d'information ou
de déplacement, imposant un vrai choix.

**Contre-jeu :** Une seule ligne active, fil détectable à proximité et
ancres destructibles.

**B --- Démon à quatre lames**

**Tags :** Projectile scindé, Ricochet, Multi-angle

**Activation et fonctionnement :** Le grand shuriken se sépare en quatre
lames après une distance choisie par recast. Chaque lame cherche l'Ancre
la plus proche de son angle et peut y ricocher une fois.

**Mécanique réelle :** Sans Ancre, les lames partent simplement en
éventail. Avec un réseau préparé, elles peuvent converger depuis
plusieurs directions.

**Synergies / intérêt :** Récompense directement la construction
géométrique des rangs D/C.

**Contre-jeu :** Les ancres révèlent les futurs angles possibles ;
détruire le réseau avant le cast rend la technique beaucoup plus simple.

**A --- Course sur câble**

**Tags :** Mobilité réseau, Attaque en mouvement, Skill expression

**Activation et fonctionnement :** Pendant quelques secondes, le Fûma
peut se verrouiller sur ses câbles et glisser à grande vitesse d'une
Ancre à une autre. Pendant le trajet, il peut lancer des armes légères
sans interrompre le mouvement.

**Mécanique réelle :** Changer de câble conserve l'élan mais chaque
transition consomme l'Ancre quittée.

**Synergies / intérêt :** Transforme le réseau préparé en parcours de
mobilité spectaculaire et offensif.

**Contre-jeu :** Préparation obligatoire, trajectoires connues à
l'avance, aucun passage à travers les obstacles et vulnérabilité aux AOE
placées sur les Ancres.

**S --- Toile des lames cardinales**

**Tags :** Réseau total, Lignes létales, Recast

**Activation et fonctionnement :** Le Fûma plante automatiquement quatre
grandes Ancres autour d'une zone et relie toutes les Ancres existantes
en une toile temporaire. À chaque recast, un grand shuriken circule sur
un segment choisi par le viseur.

**Mécanique réelle :** Le projectile accélère à chaque changement de
segment, mais ne peut pas repasser immédiatement sur le même. Les
ennemis peuvent casser les Ancres pour supprimer des routes.

**Synergies / intérêt :** Ultime entièrement basé sur la géométrie,
capable de transformer la zone en puzzle de trajectoires.

**Contre-jeu :** Aucune frappe automatique : le joueur doit choisir les
segments. Détruire deux ou trois Ancres réduit énormément le potentiel.

### Salamandre

**Identité :** Le clan Salamandre combat avec un écosystème toxique :
spores, mucus, terrain contaminé et invocations. Contrairement au Hôki,
qui adapte chimiquement ses effets à une cible, Salamandre construit une
zone de contamination persistante et joue autour de la Saturation du
terrain.

**Mécanique signature :** Contamination : certaines zones gagnent
jusqu'à 3 niveaux de Toxicité. Chaque niveau change visuellement le
terrain. Les ennemis qui restent dedans accumulent Poison mais les
effets sont progressifs ; sortir de la zone arrête l'accumulation. Les
techniques du clan peuvent consommer la Toxicité pour produire d'autres
effets.

**D --- Crachat alcalin**

**Tags :** Projectile, Terrain, Corrosion

**Activation et fonctionnement :** Une boule de mucus toxique est
crachée en cloche. Sur impact, elle crée une petite flaque de
Toxicité 1. Un ennemi directement touché reçoit un court Poison et sa
prochaine barrière temporaire est légèrement plus fragile.

**Mécanique réelle :** Deux flaques superposées montent la Toxicité du
terrain au lieu de doubler directement les dégâts.

**Synergies / intérêt :** Outil de construction de zone et
d'anti-bouclier léger.

**Contre-jeu :** Projectile lent et arc visible. Une flaque seule est
facile à contourner.

**C --- Salamandre fouisseuse**

**Tags :** Summon, Déplacement souterrain, Zone

**Activation et fonctionnement :** Une petite salamandre entre dans le
sol et se déplace vers le point ciblé, laissant une trace discrète. En
arrivant, elle surgit et crache une brume, augmentant la Toxicité locale
d'un niveau.

**Mécanique réelle :** Réactiver avant l'arrivée la fait surgir
immédiatement, utile pour surprendre mais avec une zone plus petite.

**Synergies / intérêt :** Permet d'étendre la contamination derrière une
ligne ennemie sans lancer directement une AOE visible.

**Contre-jeu :** La trace souterraine reste perceptible et la salamandre
peut être tuée après sa sortie.

**B --- Miasme dormant**

**Tags :** Gaz, Déclencheur, Consommation de zone

**Activation et fonctionnement :** Le joueur transforme une zone de
Toxicité en nuage invisible à longue distance mais légèrement ondulant
de près. Le nuage reste dormant jusqu'à ce qu'un ennemi lance un jutsu
dedans ou que le Salamandre le réactive.

**Mécanique réelle :** À l'activation, la Toxicité accumulée est
consommée pour créer une toux qui interrompt seulement les longues
canalisations et réduit la vision quelques instants.

**Synergies / intérêt :** Un vrai piège de comportement : l'adversaire
peut traverser, mais caster au mauvais moment déclenche la menace.

**Contre-jeu :** Le nuage ne fait presque pas de dégâts immédiats et
peut être dissipé par certains effets de vent ou simplement attendu.

**A --- Peau venimeuse**

**Tags :** Mode défensif, Contact, Conversion

**Activation et fonctionnement :** Le clan recouvre son corps d'un mucus
protecteur. Les dégâts de mêlée reçus laissent une petite éclaboussure
toxique au sol et réduisent progressivement la jauge de peau.

**Mécanique réelle :** Le joueur peut réactiver pour projeter le mucus
restant en arc, transformant la protection non consommée en terrain
contaminé.

**Synergies / intérêt :** Défense qui alimente directement le contrôle
de zone au lieu de donner une simple réduction de dégâts.

**Contre-jeu :** Très faible contre les attaques à distance. Les ennemis
peuvent attendre la fin ou utiliser le mucus projeté comme information
sur la future zone.

**S --- Grande Salamandre --- Souffle d'Ibuse**

**Tags :** Invocation, Nuage mobile, Terrain majeur

**Activation et fonctionnement :** Une salamandre géante apparaît et
avance lentement dans une direction commandée. Elle exhale un vaste
nuage qui augmente progressivement la Toxicité des zones traversées.

**Mécanique réelle :** Le joueur peut donner une seule seconde commande
: enfouissement, qui fait réapparaître l'invocation plus loin et crée
une rupture dans le nuage. Les zones Toxicité 3 touchées par le souffle
deviennent temporairement Suffocantes, ralentissant les mudras longs.

**Synergies / intérêt :** Ultime de conquête de terrain et de
déplacement de front.

**Contre-jeu :** Invocation lente, trajectoire annoncée, nuage
dissipable partiellement et aucune immobilisation directe. Sortir de la
contamination reste la réponse principale.

### Kaguya

**Identité :** Le clan Kaguya transforme son squelette en arsenal. Sa
ressource, la Densité osseuse, circule entre armes, armure et terrain.
Les os détachés restent brièvement comme Éclats et peuvent être
réutilisés par d'autres techniques, donnant au kit une économie
matérielle très concrète.

**Mécanique signature :** Densité : jauge qui se régénère lentement. Les
grosses techniques consomment beaucoup de Densité mais peuvent laisser
des Éclats au sol. Ramasser ou rappeler des Éclats restaure une portion
de la jauge. Le Kaguya doit donc décider quand laisser ses ressources
sur la carte.

**D --- Lame phalangienne**

**Tags :** Mêlée, Extension, Ressource

**Activation et fonctionnement :** Un os sort de l'avant-bras pour
former une lame. Le premier appui est une coupe rapide ; maintenir
prolonge l'os pour gagner de la portée au prix de Densité.

**Mécanique réelle :** Une lame prolongée brisée par une parade lourde
tombe au sol comme Éclat.

**Synergies / intérêt :** Mêlée flexible dont la portée elle-même est
une décision de ressource.

**Contre-jeu :** Allonger la lame augmente le temps de récupération et
rend le bras plus facile à lire.

**C --- Danse des côtes**

**Tags :** Parade corporelle, Pointes, Recast

**Activation et fonctionnement :** Des côtes surgissent brièvement
autour du torse. Une attaque de mêlée reçue pendant la fenêtre est
amortie et l'assaillant est repoussé par les pointes.

**Mécanique réelle :** Réactiver sans avoir bloqué une attaque expulse
deux côtes vers l'avant comme projectiles et crée des Éclats à l'impact.

**Synergies / intérêt :** Permet de ne pas perdre totalement le sort si
l'adversaire refuse la mêlée, mais avec une valeur plus faible.

**Contre-jeu :** Fenêtre courte, protection limitée au torse et
inefficace contre les grosses AOE.

**B --- Balles digitales**

**Tags :** Salve, Charges, Terrain

**Activation et fonctionnement :** Le Kaguya tire successivement des
phalanges depuis ses doigts. Chaque tir peut être légèrement orienté
indépendamment. Les impacts dans le décor créent de petits Éclats
récupérables.

**Mécanique réelle :** Maintenir le dernier tir consomme davantage de
Densité pour le faire éclater en trois fragments après un court vol.

**Synergies / intérêt :** Poke de précision pouvant aussi semer des
ressources sur la carte pour une future retraite.

**Contre-jeu :** Chaque balle est esquivable, le Kaguya doit ralentir
pour viser, et les Éclats éloignés peuvent être difficiles à récupérer.

**A --- Forêt de tessons**

**Tags :** Terrain, Éruption, Recyclage

**Activation et fonctionnement :** Le Kaguya fait jaillir une première
ligne de pointes osseuses. Tous les Éclats présents dans une grande zone
se transforment ensuite en petites pointes secondaires orientées vers la
ligne principale.

**Mécanique réelle :** Plus le joueur a laissé d'Éclats pendant le
combat, plus le motif devient complexe ; le nombre de hits par cible
reste plafonné.

**Synergies / intérêt :** Récompense la mémoire du terrain et transforme
les anciennes munitions en menace différée.

**Contre-jeu :** Sans Éclats préalables, la technique est beaucoup plus
linéaire. Les zones de pointes sont annoncées par des fissures blanches.

**S --- Shikotsumyaku --- Danse du dernier squelette**

**Tags :** Transformation, Armure offensive, Finisher

**Activation et fonctionnement :** Le Kaguya condense toute sa Densité
en une armure osseuse externe composée de segments. Chaque segment peut
être brisé par les dégâts ou volontairement arraché par le joueur pour
créer une arme temporaire : lance, bouclier ou fouet.

**Mécanique réelle :** Lorsqu'il ne reste plus qu'un segment, le joueur
peut le sacrifier pour une charge perforante qui termine immédiatement
le mode.

**Synergies / intérêt :** Ultime modulable : survivre, changer d'arme en
temps réel ou convertir toute la défense en attaque finale.

**Contre-jeu :** Chaque arme consommée réduit la protection restante. Le
mode ne régénère pas de Densité et finit rapidement si l'ennemi force
plusieurs échanges.

### Kami

**Identité :** Le clan Kami manipule des feuilles de papier-chakra comme
un essaim programmable. Le kit repose sur le nombre de Feuilles
disponibles, leur position et la possibilité de transformer le même
papier en projectile, clone, aile, cage ou explosif.

**Mécanique signature :** Feuilles : une réserve abstraite se recharge
lentement. Certaines techniques détachent des paquets de Feuilles sur le
terrain ; les rappeler restaure plus vite la ressource. Les Feuilles
peuvent être marquées comme Explosives, mais seules certaines techniques
déclenchent cette propriété.

**D --- Shuriken de papier**

**Tags :** Projectile multiple, Ressource, Marque

**Activation et fonctionnement :** Le joueur lance trois shuriken de
papier en léger éventail. Ceux qui manquent se plantent dans le décor
sous forme de Feuilles récupérables.

**Mécanique réelle :** Maintenir le cast marque le projectile central
comme Explosif au prix de ressource ; il n'explose pas encore, mais
devient une future balise.

**Synergies / intérêt :** Permet de poke tout en semant le terrain.

**Contre-jeu :** Dégâts individuels faibles, projectiles fragiles et
ressource perdue tant que les feuilles restent loin.

**C --- Clone origami**

**Tags :** Decoy, Trap, Recast

**Activation et fonctionnement :** Un clone de papier part dans la
direction choisie et imite une course simple. Au premier impact il se
désagrège en Feuilles.

**Mécanique réelle :** Réactiver le transforme volontairement en nuage
de feuilles qui bloque brièvement la vision locale. Si le clone contient
une Feuille Explosive, la dispersion provoque aussi un petit knockback.

**Synergies / intérêt :** Utilisable comme leurre, écran visuel ou
transport d'une balise explosive.

**Contre-jeu :** Le clone ne peut pas attaquer et ses mouvements sont
plus rigides qu'un vrai joueur. Les dégâts de zone le dissipent
facilement.

**B --- Ailes du papier**

**Tags :** Vol limité, Ressource continue, Pluie

**Activation et fonctionnement :** Des ailes se forment et permettent
une élévation contrôlée pendant quelques secondes. La réserve de
Feuilles se vide progressivement.

**Mécanique réelle :** Pendant le vol, les attaques de base peuvent
détacher des Feuilles vers le sol. Réactiver replie les ailes en chute
rapide et rappelle une partie des feuilles directement sous le joueur.

**Synergies / intérêt :** Mobilité verticale qui nourrit le futur
contrôle de terrain, mais possède un vrai coût économique.

**Contre-jeu :** Silhouette très visible, pas d'invulnérabilité et
vulnérabilité aux tirs précis. La réserve peut s'épuiser rapidement.

**A --- Cage de mille feuillets**

**Tags :** Zone, Barrière poreuse, Détonateurs

**Activation et fonctionnement :** Des bandes de papier tournent autour
d'une zone en formant une cage poreuse. Les personnages peuvent sortir,
mais traverser une paroi colle plusieurs Feuilles sur eux.

**Mécanique réelle :** Les Feuilles collées ne font rien seules. Le
joueur peut réactiver une fois pour faire exploser uniquement celles
marquées Explosives, tandis que les autres deviennent des balises
visibles pendant quelques secondes.

**Synergies / intérêt :** Contrôle par menace et préparation plutôt
qu'emprisonnement physique.

**Contre-jeu :** Traverser est toujours possible ; la cage coûte
beaucoup de ressource et les explosions sont faibles si le joueur n'a
pas préparé de papier explosif.

**S --- Océan de papier --- Mille détonations**

**Tags :** Domaine, Ressource totale, Chaîne programmable

**Activation et fonctionnement :** Le sol d'une grande zone se couvre de
bandes de papier issues de toute la réserve restante. Le joueur trace
jusqu'à trois chemins de détonation avec son viseur ; les explosions
parcourent ensuite ces chemins dans l'ordre choisi.

**Mécanique réelle :** Chaque chemin est annoncé une fraction de seconde
avant d'exploser. Les Feuilles Explosives déjà placées sur le terrain
s'ajoutent comme embranchements.

**Synergies / intérêt :** Ultime de planification : le joueur dessine
littéralement le pattern de danger et peut utiliser tout ce qu'il a semé
auparavant.

**Contre-jeu :** Après l'ultime, la réserve est presque vide. Les
chemins sont visibles et n'explosent pas simultanément, laissant des
routes d'esquive.

## Kiri

### Hôzuki

**Identité :** Le clan Hôzuki alterne entre corps solide et corps
liquide. Son Hydratation est une vraie ressource : se liquéfier évite ou
amortit certains impacts, mais consomme de l'eau corporelle. Le joueur
doit ensuite récupérer cette Hydratation via ses techniques ou des
surfaces d'eau.

**Mécanique signature :** Hydratation : jauge de 0 à 100. Les formes
liquides la consomment, les techniques d'eau et le contact prolongé avec
des surfaces d'Eau la restaurent. À Hydratation faible, les techniques
physiques restent disponibles mais perdent leurs variantes liquides.

**D --- Corps fluide**

**Tags :** Parade, Ressource, Esquive partielle

**Activation et fonctionnement :** Le Hôzuki liquéfie son torse pendant
une très courte fenêtre. Une attaque physique directe reçue traverse
partiellement et voit son impact réduit ; l'attaque laisse le Hôzuki
éclaboussé sur une petite zone avant qu'il se reforme.

**Mécanique réelle :** La parade consomme de l'Hydratation en fonction
de la puissance absorbée. Les attaques électriques ou de zone ne sont
pas neutralisées et certaines peuvent coûter davantage.

**Synergies / intérêt :** Outil signature, fort mais impossible à
spammer sans gérer la jauge.

**Contre-jeu :** Fenêtre courte, coût proportionnel et contres
élémentaires clairs. Rater la parade gaspille une petite quantité
d'Hydratation.

**C --- Pistolet à eau**

**Tags :** Hitscan chargé, Ressource, Recul

**Activation et fonctionnement :** Le Hôzuki forme un pistolet avec ses
doigts et tire une goutte hyperpressurisée. Le tir est très rapide et
gagne en puissance si le joueur maintient brièvement la charge.

**Mécanique réelle :** À charge maximale, le recul fait glisser
légèrement le lanceur en sens inverse. Sur une surface d'Eau, ce recul
devient un véritable petit dash.

**Synergies / intérêt :** Poke de précision qui peut devenir mobilité
situationnelle.

**Contre-jeu :** Charge sonore identifiable, ligne très fine et coût
d'Hydratation plus élevé à pleine puissance.

**B --- Flaque vivante**

**Tags :** Transformation, Mobilité au sol, Ambush

**Activation et fonctionnement :** Le Hôzuki se transforme en flaque et
glisse rapidement au sol pendant quelques secondes. Il peut passer sous
certains obstacles bas mais ne peut pas attaquer.

**Mécanique réelle :** Réactiver reforme le corps avec une éclaboussure
qui repousse légèrement. Traverser une surface d'Eau réduit le coût de
maintien.

**Synergies / intérêt :** Outil d'infiltration et de repositionnement
réellement différent d'un dash.

**Contre-jeu :** La flaque reste visible, vulnérable aux AOE et
particulièrement aux effets électriques. La sortie possède un bref temps
de reformage.

**A --- Bras hydraulique**

**Tags :** Mêlée chargée, Masse variable, Recast

**Activation et fonctionnement :** Le bras se gonfle d'eau sous
pression. Le premier coup est une frappe lourde ; si elle manque, le
joueur peut réactiver pour expulser l'eau du bras et générer un jet
latéral qui repousse.

**Mécanique réelle :** Plus l'Hydratation investie est grande, plus le
bras est large et lent. Le joueur choisit donc sa masse au lancement.

**Synergies / intérêt :** Donne un vrai curseur risque/récompense entre
grosse hitbox lente et petit coup rapide.

**Contre-jeu :** Investissement visible, coût de ressource et
récupération importante après une frappe lourde.

**S --- Démon d'eau --- Corps torrentiel**

**Tags :** Transformation, Morphologie, Ressource

**Activation et fonctionnement :** Le Hôzuki transforme presque tout son
corps en masse liquide géante. Il gagne de grandes enjambées, peut
déformer sa hitbox latéralement et ses coups créent des vagues courtes.

**Mécanique réelle :** La jauge d'Hydratation devient la durée du mode.
Subir des dégâts fait perdre de l'eau supplémentaire ; traverser de
l'Eau en restaure un peu. Un recast condense tout le volume restant en
un unique jet de pression, terminant le mode.

**Synergies / intérêt :** Ultime entièrement gouverné par la ressource
et la géographie du terrain.

**Contre-jeu :** Très visible, vulnérable au Raiton et aux zones qui
frappent en continu. Le finisher sacrifie toute durée restante.

### Hoshigaki

**Identité :** Le clan Hoshigaki est un prédateur de chakra. Il devient
plus dangereux lorsqu'il reste au contact d'ennemis Trempés ou à faible
chakra, mais ne vole jamais gratuitement des ressources. Sa jauge de
Faim se construit par pression agressive et peut être dépensée pour
renforcer les techniques aquatiques bestiales.

**Mécanique signature :** Faim : jusqu'à 3 charges gagnées en infligeant
des dégâts significatifs à une cible Trempée, en interrompant un jutsu
ou en frappant une cible sous un seuil de chakra. Les charges expirent
hors combat et sont consommées par les techniques avancées.

**D --- Morsure du requin**

**Tags :** Dash court, Mêlée, Ressource

**Activation et fonctionnement :** Le Hoshigaki bondit sur une courte
distance et mord/frappe la première cible rencontrée. Si elle est
Trempée ou vient de dépenser du chakra, le coup génère 1 Faim.

**Mécanique réelle :** Le dash ne traverse pas les ennemis et n'est pas
invulnérable ; il s'agit d'une fermeture de distance.

**Synergies / intérêt :** Moteur de ressource simple qui encourage
l'agression opportuniste.

**Contre-jeu :** Portée courte, trajectoire droite et punissable si le
bond manque.

**C --- Siphon branchial**

**Tags :** Canalisation courte, Chakra, Duel

**Activation et fonctionnement :** Le Hoshigaki saisit ou maintient un
cône très proche devant lui et aspire une petite quantité de chakra aux
ennemis touchés. La quantité volée est plafonnée ; l'objectif principal
est d'empêcher une récupération confortable.

**Mécanique réelle :** Consommer 1 Faim transforme une partie du chakra
aspiré en bouclier temporaire plutôt qu'en ressource personnelle.

**Synergies / intérêt :** Permet de choisir entre prolonger son propre
casting ou sécuriser un engage.

**Contre-jeu :** Très courte portée, canalisation interruptible et
rendement fortement réduit contre une cible déjà presque vide.

**B --- Requin pisteur**

**Tags :** Invocation projectile, Tracking conditionnel, Faim

**Activation et fonctionnement :** Un requin d'eau est lancé en ligne.
S'il traverse une surface d'Eau ou passe près d'une cible Trempée, il
peut effectuer une seule correction de trajectoire vers elle.

**Mécanique réelle :** Consommer 1 Faim permet au requin de se diviser à
l'impact en deux petites mâchoires latérales qui zonent les esquives.

**Synergies / intérêt :** Projectile de chasse qui reste évitable et
devient meilleur si le Hoshigaki a préparé l'environnement.

**Contre-jeu :** Correction unique, obstacles solides et projectile
visible. Une cible sèche en terrain ouvert le rend très banal.

**A --- Frénésie des branchies**

**Tags :** Mode prédateur, Ressource, Anti-fuite

**Activation et fonctionnement :** Le Hoshigaki dépense toutes ses
charges de Faim pour entrer en Frénésie. Chaque charge augmente la
durée, pas les dégâts bruts. Pendant le mode, il gagne vitesse de
nage/glisse et voit les traces de chakra récentes laissées par les
dashes ennemis.

**Mécanique réelle :** Interrompre un jutsu pendant la Frénésie prolonge
légèrement le mode une seule fois.

**Synergies / intérêt :** Pic de chasse basé sur l'information et le
tempo, pas un steroid de dégâts simpliste.

**Contre-jeu :** Aucune charge = mode très court. Les traces n'indiquent
pas la position actuelle et une cible qui cesse de gaspiller ses
mouvements réduit l'avantage.

**S --- Grand requin dévoreur de chakra**

**Tags :** Projectile massif, Absorption, Croissance

**Activation et fonctionnement :** Un énorme requin d'eau avance
lentement. Les projectiles de chakra non ultimes qu'il rencontre sont
partiellement absorbés, augmentant sa taille et la portée de son
explosion finale.

**Mécanique réelle :** Chaque absorption consomme aussi une partie du
projectile : les très gros jutsu ne sont pas entièrement annulés. Le
joueur peut réactiver pour faire plonger le requin plus tôt et libérer
l'énergie absorbée.

**Synergies / intérêt :** Ultime anti-spam emblématique : plus
l'adversaire panique et tire dedans, plus la menace grossit.

**Contre-jeu :** Lent, évitable, vulnérable aux attaques physiques et
aux angles latéraux. Ne jamais permettre l'absorption intégrale d'un
ultime.

### Yuki

**Identité :** Le clan Yuki joue avec le Froid et des Miroirs de glace.
Les stacks de Givre réduisent progressivement l'adhérence et la
précision des mouvements sans hard-stun immédiat. Les Miroirs sont des
points de téléportation et de réflexion, ce qui crée un kit de mobilité
géométrique.

**Mécanique signature :** Givre : maximum 4 stacks. Chaque stack
augmente légèrement la glisse après un changement brusque de direction.
À 4 stacks, la prochaine technique Yuki qui touche peut déclencher Gel
bref puis remet le compteur à zéro. Les Miroirs sont destructibles et
limités en nombre.

**D --- Senbon de givre**

**Tags :** Projectile rapide, Stack, Poke

**Activation et fonctionnement :** Le Yuki lance une aiguille de glace
rapide qui applique 1 Givre. Si elle frappe un mur, elle crée un
minuscule éclat réfléchissant qui indique un futur angle de Miroir sans
en être un véritable.

**Mécanique réelle :** Toucher une cible déjà à 4 stacks consomme le
seuil et la ralentit fortement un très court instant plutôt que de
l'immobiliser totalement.

**Synergies / intérêt :** Setup précis et lisible pour toute la
progression.

**Contre-jeu :** Faible dégâts, projectile fin et Givre expirant si le
Yuki n'entretient pas la pression.

**C --- Miroir de glace**

**Tags :** Objet, Téléportation, Angle

**Activation et fonctionnement :** Le Yuki place un Miroir sur une
surface valide. Jusqu'à deux peuvent exister. Appuyer à nouveau près
d'un Miroir téléporte le joueur vers l'autre avec un bref délai de
matérialisation.

**Mécanique réelle :** Les petits projectiles Yuki qui frappent un
Miroir ressortent une fois de l'autre avec une légère perte de vitesse.

**Synergies / intérêt :** Crée un réseau simple mais profond de mobilité
et d'angles de tir.

**Contre-jeu :** Miroirs visibles, destructibles et téléportation
impossible si la sortie est obstruée. Le délai de sortie est
exploitable.

**B --- Patinoire fracturée**

**Tags :** Terrain, Glisse, Fissures

**Activation et fonctionnement :** Une longue plaque de glace apparaît
au sol. Tous les personnages glissent davantage dessus. Chaque dash ou
impact lourd crée une Fissure ; après trois Fissures, la plaque éclate
et projette des fragments.

**Mécanique réelle :** Le Yuki peut volontairement déclencher
l'éclatement avec un Senbon dans une Fissure, créant un timing contrôlé.

**Synergies / intérêt :** Terrain interactif dont les deux équipes
peuvent profiter ou souffrir.

**Contre-jeu :** Zone visible et neutre : un ennemi habile peut utiliser
la glisse à son avantage. L'éclatement est annoncé par l'état de la
glace.

**A --- Labyrinthe des miroirs**

**Tags :** Multi-objet, Téléportation séquencée, Illusion légère

**Activation et fonctionnement :** Quatre Miroirs temporaires
apparaissent autour d'une zone. Le Yuki peut se déplacer instantanément
entre deux Miroirs adjacents à intervalles courts. Chaque déplacement
laisse une silhouette de glace qui continue un pas avant de se briser.

**Mécanique réelle :** Les projectiles de Senbon peuvent traverser au
maximum deux Miroirs pendant le labyrinthe, permettant des angles
complexes.

**Synergies / intérêt :** Kit de duel spatial à haut skill-cap, fondé
sur un réseau destructible.

**Contre-jeu :** Les Miroirs peuvent être détruits, les routes sont
limitées aux adjacences et les silhouettes ne masquent pas les effets
sonores réels.

**S --- Zéro absolu --- Cercueil cristallin**

**Tags :** Domaine froid, Gestion de stacks, Finisher

**Activation et fonctionnement :** Une tempête de glace entoure une
grande zone et applique progressivement Givre à tous, Yuki compris plus
lentement. Les Miroirs présents se renforcent et deviennent
temporairement plus difficiles à détruire.

**Mécanique réelle :** Quand une cible atteint 4 Givres dans le domaine,
le Yuki peut consommer le seuil pour faire surgir autour d'elle trois
plaques de glace qui se referment après un délai. La cible peut encore
sortir avant fermeture ou casser une plaque.

**Synergies / intérêt :** Ultime qui transforme la gestion des stacks en
menace de capture sans prison instantanée.

**Contre-jeu :** Montée lente, domaine fixe, plaques destructibles et
possibilité claire de quitter la zone avant accumulation maximale.

### Karatachi

**Identité :** Proposition d'identité pour Karatachi : chakra de corail,
carapace et récif. Le kit crée des Nœuds de corail sur les surfaces et
les personnages, puis les fait pousser en structures défensives ou
offensives. Cela donne à Kiri un contrôleur de terrain minéral très
différent du Doton : le corail se propage par réseau plutôt que par
masse brute.

**Mécanique signature :** Calcification : les techniques posent des
Nœuds de corail, maximum 5. Deux Nœuds proches peuvent se relier par une
Crête. Les Nœuds sur ennemi ne bloquent pas ses mouvements mais rendent
certaines poussées de corail plus faciles à orienter. Les structures
sont cassables.

**D --- Épine de corail**

**Tags :** Projectile, Node, Terrain

**Activation et fonctionnement :** Une pointe de corail est tirée en
ligne. Sur terrain, elle crée un Nœud. Sur ennemi, elle s'accroche
brièvement comme Nœud mobile et inflige de faibles dégâts.

**Mécanique réelle :** Le Nœud ennemi tombe au sol s'il expire, donnant
encore une petite valeur de terrain.

**Synergies / intérêt :** Moteur de construction du réseau.

**Contre-jeu :** Projectile visible, dégâts faibles et nombre maximum
strict de Nœuds.

**C --- Écaille récifale**

**Tags :** Bouclier local, Riposte, Node

**Activation et fonctionnement :** Une plaque de corail pousse sur un
côté du corps choisi au cast. Elle absorbe une portion d'un impact
venant de cet angle puis éclate en deux petits Nœuds sur le sol.

**Mécanique réelle :** Si elle n'est pas brisée, le joueur peut la
détacher volontairement et la planter comme grand Nœud.

**Synergies / intérêt :** Défense directionnelle qui alimente ensuite le
terrain.

**Contre-jeu :** Un seul côté protégé, contournable par les angles et
AOE.

**B --- Crête jaillissante**

**Tags :** Ligne entre nodes, Terrain, Launcher

**Activation et fonctionnement :** Le Karatachi choisit deux Nœuds. Une
crête de corail pousse progressivement entre eux. Les ennemis au-dessus
sont légèrement soulevés et déplacés vers le côté le plus proche.

**Mécanique réelle :** La crête reste comme obstacle bas destructible.
Un Nœud attaché à un ennemi peut servir de point mobile, mais la
croissance s'arrête si la distance devient trop grande.

**Synergies / intérêt :** Permet des murs dynamiques et des trajectoires
inattendues, surtout avec un Nœud mobile.

**Contre-jeu :** Préparation nécessaire, croissance visible et
structures cassables.

**A --- Récif prédateur**

**Tags :** Réseau, Propagation, Piège progressif

**Activation et fonctionnement :** Tous les Nœuds actifs commencent à
pousser lentement vers le Nœud voisin le plus proche. Lorsque deux
pousses se rencontrent, elles créent une bouche de corail qui se ferme
une fois sur le premier ennemi qui la traverse, provoquant une brève
saisie des jambes.

**Mécanique réelle :** Après fermeture, la bouche devient simple
obstacle. Le joueur peut donc transformer son réseau en une série de
pièges à usage unique.

**Synergies / intérêt :** Récompense énormément la préparation des rangs
précédents et la lecture des chemins.

**Contre-jeu :** Les lignes de pousse sont visibles et lentes. Détruire
un Nœud avant connexion casse toute une branche.

**S --- Sanctuaire de la tortue corallienne**

**Tags :** Forteresse réseau, Bouclier partagé, Recast

**Activation et fonctionnement :** Le Karatachi fait croître une grande
carapace de corail autour de ses Nœuds existants. Chaque Nœud devient un
pilier relié aux autres ; les alliés proches d'un pilier reçoivent un
petit bouclier partagé avec celui-ci.

**Mécanique réelle :** Réactiver fait éclater les piliers restants vers
l'extérieur en éventails de fragments ; plus on conserve de piliers
défensifs, plus le final couvre d'angles, mais la forteresse disparaît.

**Synergies / intérêt :** Ultime à bascule défense/offense basé sur
l'état réel du réseau.

**Contre-jeu :** Très dépendant des Nœuds préalables. Les piliers
peuvent être focus et l'explosion finale est annoncée par une vibration
du récif.

### Épéistes

**Identité :** Les Épéistes jouent autour de la maîtrise de l'arme, de
la garde et du Tempo de lame. Le kit doit rester compatible avec
différents modèles d'épées : les techniques décrivent des principes de
combat plutôt qu'une arme légendaire spécifique. Le joueur accumule du
Fil en réussissant des actions techniques, puis le dépense pour des
manœuvres avancées.

**Mécanique signature :** Fil : jusqu'à 3 charges gagnées par parade
réussie, attaque touchée en bout de portée ou récupération correcte
d'une arme lancée. Le Fil améliore la précision, le déplacement ou la
garde de certaines techniques, pas simplement leurs dégâts.

**D --- Iai de garde**

**Tags :** Parade, Draw attack, Ressource

**Activation et fonctionnement :** L'Épéiste rengaine brièvement puis
dégaine dans un arc. Si une attaque de mêlée entre pendant la fenêtre
initiale, elle est parée et le coup sort plus vite, générant 1 Fil.

**Mécanique réelle :** Sans parade, l'attaque reste une coupe normale
mais plus lente.

**Synergies / intérêt :** Apprend immédiatement le rythme
défensif/offensif du kit.

**Contre-jeu :** Fenêtre de parade courte, aucune protection contre la
distance ou les AOE et récupération longue si le coup whiff.

**C --- Lame en rappel**

**Tags :** Throw, Retrieval, Positioning

**Activation et fonctionnement :** L'Épéiste lance son arme en rotation.
Elle se plante dans une surface ou tombe après impact. Tant qu'elle est
au sol, le joueur combat avec une garde réduite mais peut réactiver pour
rappeler l'arme en ligne droite.

**Mécanique réelle :** Toucher une cible avec le retour génère 1 Fil.
Dépenser 1 Fil permet au joueur de faire un petit pas vers l'arme au
moment du rappel, réduisant la distance.

**Synergies / intérêt :** Crée un axe dangereux aller/retour et une
vraie période de vulnérabilité sans arme.

**Contre-jeu :** Trajectoire de retour prévisible ; un adversaire peut
se placer hors ligne et profiter de la garde réduite.

**B --- Brise-garde du bourreau**

**Tags :** Heavy attack, Guard break, Feint

**Activation et fonctionnement :** Une frappe lourde est préparée avec
un long télégraphe. Le joueur peut annuler volontairement la préparation
en consommant 1 Fil et effectuer à la place une petite coupe latérale
rapide.

**Mécanique réelle :** Si la frappe lourde touche une garde ou un
bouclier, elle inflige surtout des dégâts de posture et repousse ; sur
une cible sans garde, les dégâts restent modérés pour éviter l'one-shot.

**Synergies / intérêt :** Le vrai pouvoir est le mindgame entre charge
et feinte.

**Contre-jeu :** Sans Fil, aucune feinte. La frappe lourde est très
facile à esquiver si le joueur la lance sans setup.

**A --- Duel dans la brume rouge**

**Tags :** Zone duel, Information, Tempo

**Activation et fonctionnement :** L'Épéiste crée une brume basse autour
de lui et d'une cible proche. Les deux restent visibles l'un pour
l'autre à courte portée mais les alliés extérieurs voient des
silhouettes moins précises à travers la brume.

**Mécanique réelle :** Dans la zone, réussir une parade ou un sweet spot
donne immédiatement 1 Fil ; subir un contrôle lourd dissipe la brume. La
cible peut sortir librement mais révèle alors sa trajectoire par une
traînée.

**Synergies / intérêt :** Crée un espace de duel sans enfermer ni isoler
techniquement le joueur adverse.

**Contre-jeu :** Quitter la zone est toujours possible. Les AOE externes
continuent de fonctionner et l'Épéiste ne gagne aucune immunité.

**S --- Maîtrise des sept lames**

**Tags :** Mode, Arsenal abstrait, Choix séquencé

**Activation et fonctionnement :** Pendant quelques secondes, l'Épéiste
peut dépenser ses charges de Fil pour invoquer des "formes" spectrales
d'armes : Forme lourde pour bloquer un frontal, Forme longue pour
étendre une coupe, Forme double pour effectuer deux frappes croisées.

**Mécanique réelle :** Chaque Forme ne peut être utilisée qu'une fois
par activation et modifie la prochaine technique ou attaque, puis
disparaît. La maîtrise vient de l'ordre choisi, pas d'un simple buff
global.

**Synergies / intérêt :** Ultime compatible avec n'importe quelle arme
réelle, riche en décisions et en expression mécanique.

**Contre-jeu :** Le mode ne crée pas de Fil gratuitement. Un joueur qui
entre sans ressource n'a que la forme de base et perd une grande partie
du potentiel.

# 6. Sub-jutsu --- pool de 30 techniques

**Principe :** les Sub-jutsu sont volontairement plus atypiques que les
arbres standards. Ils ne doivent pas devenir des versions supérieures de
techniques de clan : leur valeur vient d'une règle spéciale, d'un risque
ou d'une flexibilité inhabituelle. Répartition proposée pour ce pool :
12 rang B, 10 rang A et 8 rang S. Le rang exact accessible par les
tirages reste une règle de progression séparée.

## Rang B

**B --- Shunshin --- Double empreinte**

**Tags :** Mobilité, Recast, Feinte

**Activation et fonctionnement :** Le joueur marque discrètement son
point de départ puis effectue un déplacement éclair court dans la
direction visée. Pendant une seconde, il peut réactiver pour revenir
exactement sur l'empreinte initiale.

**Mécanique réelle :** Le retour conserve l'orientation actuelle, ce qui
permet de feinter un engage, traverser une ligne de menace ou forcer une
réaction avant de revenir. L'empreinte ne peut pas être placée en l'air
ou derrière un mur non franchi.

**Synergies / intérêt :** Sub-jutsu universel à forte expression
mécanique : sa puissance vient du timing du recast, pas d'une
invulnérabilité longue.

**Contre-jeu :** L'empreinte est brièvement visible au sol. Les dégâts
et contrôles reçus ne sont pas annulés par le retour ; un adversaire
peut piéger le point de départ.

**B --- Clone explosif tactique**

**Tags :** Decoy, Recast, Piège

**Activation et fonctionnement :** Un clone part dans une direction et
reproduit les déplacements simples du joueur avec un léger retard
pendant quelques secondes. Il n'attaque pas réellement.

**Mécanique réelle :** Le joueur peut le faire exploser manuellement ;
s'il est détruit par un ennemi, il explose plus faiblement. L'explosion
repousse et pose une marque sonore, mais ses dégâts restent modérés.

**Synergies / intérêt :** Permet de casser un lock, contrôler un angle
ou préparer une attaque depuis le côté opposé.

**Contre-jeu :** Le clone possède des mouvements légèrement artificiels
et un seul point de vie. L'ignorer est souvent la meilleure réponse.

**B --- Paume d'absorption de chakra**

**Tags :** Parade, Ressource, Anti-jutsu

**Activation et fonctionnement :** Le joueur ouvre une courte fenêtre de
garde dans la paume. Le premier projectile ou impact de chakra
compatible touchant le cône frontal est partiellement absorbé.

**Mécanique réelle :** Une portion plafonnée du coût estimé est rendue
en chakra au joueur ; l'attaque n'est jamais totalement annulée si elle
est lourde. Réussir l'absorption réduit brièvement le coût du prochain
mudra.

**Synergies / intérêt :** Récompense une parade précise et peut
retourner le tempo d'un duel de ressources.

**Contre-jeu :** Fenêtre courte, directionnelle, inefficace contre
attaques physiques, zones persistantes et ultimes.

**B --- Voile de brume silencieuse**

**Tags :** Zone, Vision, Son

**Activation et fonctionnement :** Une brume dense apparaît autour d'un
point. À l'intérieur, la vision à moyenne distance est réduite et les
noms/indicateurs de cible s'effacent au-delà d'une courte portée.

**Mécanique réelle :** Le lanceur ne voit pas parfaitement non plus,
mais les pas rapides créent pour lui de brefs anneaux sonores au sol.
Rester immobile ou marcher lentement minimise ces indices.

**Synergies / intérêt :** Crée un minijeu de chasse et de son, utile à
de nombreux builds sans remplacer les capacités de Traqueur.

**Contre-jeu :** Zone fixe, silhouettes visibles à courte portée et
attaques révélant toujours leur origine.

**B --- Réseau de parchemins explosifs**

**Tags :** Piège, Chaîne, Programmation

**Activation et fonctionnement :** Le joueur peut poser jusqu'à trois
parchemins sur surfaces valides. Réactiver fait exploser celui qui est
le plus proche du viseur ; une explosion qui touche la zone d'un autre
parchemin le déclenche après un petit délai.

**Mécanique réelle :** La chaîne suit donc réellement la géométrie du
placement. Le joueur peut espacer les explosions pour fermer une route
plutôt que tout faire partir simultanément.

**Synergies / intérêt :** Sub-jutsu de préparation et de zoning très
lisible.

**Contre-jeu :** Parchemins visibles de près, destructibles et temps de
pose vulnérable.

**B --- Fil de chakra manipulateur**

**Tags :** Tether, Projectile control, Utility

**Activation et fonctionnement :** Un fil de chakra s'accroche à un
petit projectile allié, une arme au sol ou un ennemi très proche. Sur
projectile, le joueur peut courber légèrement sa trajectoire ; sur arme,
la rappeler ; sur ennemi, seulement perturber un saut ou un dash léger.

**Mécanique réelle :** Le fil casse sur obstacle ou distance excessive
et ne peut pas contrôler un personnage en continu.

**Synergies / intérêt :** Outil polyvalent qui devient puissant avec la
créativité du joueur et les projectiles de son build.

**Contre-jeu :** Portée courte, ligne visible et aucun hard-CC.

**B --- Fausse ouverture**

**Tags :** Stance, Counter, Mindgame

**Activation et fonctionnement :** Le joueur adopte volontairement une
posture qui ralentit légèrement son mouvement et affiche une animation
de récupération crédible. S'il reçoit une attaque de mêlée pendant la
fenêtre, il peut réactiver pour esquiver d'un demi-pas et frapper en
retour.

**Mécanique réelle :** Sans attaque ennemie, la posture se termine avec
une vraie petite récupération : feinter comporte donc un risque.

**Synergies / intérêt :** Crée un outil de mindgame universel sans
simple bouton d'invulnérabilité.

**Contre-jeu :** Les attaques à distance, grabs et patience adverses
punissent très bien la posture.

**B --- Danse des câbles kunai**

**Tags :** Anchors, Mobility, Skillshot

**Activation et fonctionnement :** Le joueur lance jusqu'à trois kunai
reliés par câble. Les kunai se plantent dans le décor. Tant qu'au moins
un reste actif, le joueur peut se tirer vers une ancre ou effectuer un
swing court autour d'elle.

**Mécanique réelle :** Chaque ancre n'autorise qu'un déplacement avant
de se décrocher. Un kunai qui touche un ennemi ne l'ancre pas : il
rebondit au sol pour éviter un grappin gratuit sur joueur.

**Synergies / intérêt :** Sub-jutsu de mobilité technique basé sur le
décor.

**Contre-jeu :** Nécessite des surfaces, trajectoires visibles, aucune
invulnérabilité et ancrages destructibles.

**B --- Pulsation sensorielle**

**Tags :** Reveal, Anti-decoy, Interrupt léger

**Activation et fonctionnement :** Une onde de chakra part du joueur et
révèle pendant un instant les silhouettes, clones, pièges et invocations
dans une portée moyenne.

**Mécanique réelle :** Les longues canalisations ennemies déjà actives
reçoivent une petite secousse uniquement si le lanceur est très proche ;
l'objectif principal reste l'information.

**Synergies / intérêt :** Contre les kits d'illusion et permet de
sécuriser une zone avant d'entrer.

**Contre-jeu :** Cooldown important, aucune vision permanente et
obstacles épais réduisant la portée.

**B --- Lame de chakra fluide**

**Tags :** Weapon enchant, Parry projectile, Recast

**Activation et fonctionnement :** Une arme de mêlée ou l'avant-bras
reçoit une lame de chakra pendant quelques secondes. Une coupe
parfaitement timée contre un petit projectile le fend et stocke une
Impulsion.

**Mécanique réelle :** Le prochain coup lourd peut consommer l'Impulsion
pour envoyer une courte lame d'air neutre. Une seule Impulsion peut être
stockée.

**Synergies / intérêt :** Offre une défense active aux combattants de
mêlée et transforme une réussite technique en option de poke.

**Contre-jeu :** Fenêtre de coupe précise, aucun effet contre gros
projectiles ou AOE.

**B --- Substitution à balise**

**Tags :** Mark, Reactive swap, Terrain

**Activation et fonctionnement :** Le joueur pose une balise de
substitution sur un petit objet de décor ou un point au sol. Pendant
quelques secondes, lorsqu'il est frappé par une attaque directe, il
dispose d'une très courte fenêtre pour échanger sa position avec la
balise.

**Mécanique réelle :** Le swap ne retire pas les dégâts déjà reçus ; il
sert à éviter le follow-up. La balise est détruite après usage.

**Synergies / intérêt :** Récompense la préparation et permet de casser
un combo sans effacer l'erreur initiale.

**Contre-jeu :** Balise visible, portée limitée, pas de swap si
l'emplacement est occupé ou hors ligne spatiale valide.

**B --- Sceau d'écho sonore**

**Tags :** Trap, Sound, Delayed trigger

**Activation et fonctionnement :** Le joueur place un petit sceau
sonore. Il enregistre le premier jutsu lancé à proximité sous forme
d'une signature acoustique.

**Mécanique réelle :** Le lanceur peut réactiver pour rejouer uniquement
le son et le télégraphe initial du jutsu depuis le sceau, sans aucun
effet réel. Cela peut provoquer une esquive ou masquer le vrai début
d'une autre technique.

**Synergies / intérêt :** Sub-jutsu purement informationnel et mental,
extrêmement unique.

**Contre-jeu :** Un seul enregistrement, sceau destructible et joueurs
expérimentés pouvant reconnaître l'absence d'autres indices visuels.

## Rang A

**A --- Réseau de clones relais**

**Tags :** Clones, Swap, Multi-position

**Activation et fonctionnement :** Trois clones fragiles sont créés en
triangle autour du joueur et reproduisent ses déplacements avec un léger
décalage. Chaque clone meurt au premier impact sérieux.

**Mécanique réelle :** Le joueur peut réactiver une fois pour échanger
instantanément sa position avec le clone visé. Les clones n'infligent
pas de vrais dégâts mais imitent le début des animations.

**Synergies / intérêt :** Outil de positionnement et de mindgame à très
haut skill-cap.

**Contre-jeu :** Les clones sont fragiles et les AOE peuvent nettoyer le
réseau. Le swap unique doit être choisi avec soin.

**A --- Barrière des quatre coins**

**Tags :** Setup, Prison ouverte, Objectif

**Activation et fonctionnement :** Le joueur place quatre petits pylônes
de chakra, un par un. Lorsque le quatrième est posé, les pylônes se
relient pour former une barrière.

**Mécanique réelle :** Les personnages peuvent traverser les parois,
mais chaque traversée consomme beaucoup plus de chakra pour le prochain
jutsu pendant quelques secondes. Détruire un pylône ouvre un côté et
annule cet effet sur cette paroi.

**Synergies / intérêt :** Contrôle de zone basé sur une taxe de
ressource plutôt qu'un mur absolu.

**Contre-jeu :** Longue préparation, pylônes destructibles et aucune
valeur si le joueur n'arrive pas à fermer le quadrilatère.

**A --- Huit Portes --- Porte de la Vie**

**Tags :** Transformation, HP cost, Tempo

**Activation et fonctionnement :** Le joueur ouvre une Porte interne
pendant quelques secondes : vitesse, accélération et récupération des
attaques physiques augmentent nettement.

**Mécanique réelle :** Chaque seconde active accumule Fatigue. À la
fermeture, la Fatigue devient une perte de PV non létale et un
ralentissement proportionnel pendant un court moment. Le joueur peut
couper tôt pour limiter la dette.

**Synergies / intérêt :** Pic de tempo extrêmement fort mais avec une
dette réelle après le combat.

**Contre-jeu :** Télégraphe clair, aucun bonus aux jutsu à distance et
punition sévère si l'adversaire kite jusqu'à la phase de Fatigue.

**A --- Marque d'échange spatio-temporel**

**Tags :** Two-point swap, Setup, Recast

**Activation et fonctionnement :** Le joueur place une première marque
puis une seconde sur deux surfaces distinctes. Pendant quelques
secondes, il peut réactiver pour échanger instantanément le contenu
léger des deux petites zones : lui-même, un clone, une invocation légère
ou un projectile compatible.

**Mécanique réelle :** Les joueurs ennemis ne sont jamais téléportés de
force, mais un projectile peut être déplacé d'une porte à l'autre.

**Synergies / intérêt :** Outil de créativité immense pour les combos et
la défense.

**Contre-jeu :** Deux placements nécessaires, marques visibles et
distance maximale stricte.

**A --- Surcadençage du réseau de chakra**

**Tags :** Cooldown manipulation, Heat, Risk

**Activation et fonctionnement :** Le joueur accélère son réseau de
chakra pendant une courte durée. Le prochain jutsu non ultime récupère
une partie importante de son cooldown immédiatement après utilisation.

**Mécanique réelle :** En échange, le joueur gagne Surchauffe : pendant
quelques secondes, ses coûts en chakra augmentent et il ne peut pas
réutiliser Surcadençage. Le même jutsu ne peut pas être reset deux fois
de suite.

**Synergies / intérêt :** Permet des combos exceptionnels sans devenir
une réduction de cooldown permanente.

**Contre-jeu :** Fenêtre très lisible et dette de ressource importante ;
utiliser le reset sur le mauvais sort est très punitif.

**A --- Marque maudite --- Stade I**

**Tags :** Mode, Resource corruption, Choice

**Activation et fonctionnement :** Une marque se répand sur le corps. Le
joueur gagne vitesse de mudra et puissance de chakra, mais chaque jutsu
lancé remplit une jauge de Corruption.

**Mécanique réelle :** À certains seuils, la Corruption réduit la
récupération de chakra puis commence à infliger une faible perte de PV.
Le joueur peut couper le mode quand il veut ; la Corruption descend
lentement ensuite.

**Synergies / intérêt :** Pic offensif modulable où le joueur choisit
consciemment jusqu'où aller.

**Contre-jeu :** Aucune défense supplémentaire et risque croissant.
Forcer le joueur à caster beaucoup accélère sa propre dette.

**A --- Orbite des mille senbon**

**Tags :** Persistent projectiles, Trigger, Anti-mobility

**Activation et fonctionnement :** Des dizaines de senbon de chakra
restent suspendus autour d'une zone en anneau. Ils ne tirent pas
immédiatement.

**Mécanique réelle :** Chaque dash ennemi à l'intérieur déclenche une
petite salve depuis la portion d'anneau la plus proche. Le joueur peut
réactiver pour tirer le reste vers le centre, mettant fin au piège.

**Synergies / intérêt :** Punition conditionnelle de la mobilité, pas
une pluie automatique.

**Contre-jeu :** Marcher normalement ne déclenche rien. L'anneau est
visible et sa fermeture finale est télégraphiée.

**A --- Sceau de suppression majeure**

**Tags :** Skillshot, Chakra tax, Reveal

**Activation et fonctionnement :** Un grand talisman est projeté
lentement. S'il colle à une cible, il augmente temporairement le coût de
ses jutsu et affiche une pulsation avant chaque mudra.

**Mécanique réelle :** La cible peut retirer le sceau en restant
immobile une courte durée ou un allié peut le frapper pour l'arracher.

**Synergies / intérêt :** Crée une fenêtre de pression sur les gros
casters tout en offrant un contre-jeu actif.

**Contre-jeu :** Projectile lent, sceau retirable et aucun silence
complet.

**A --- Invocation --- Faucon de relais**

**Tags :** Summon, Vision, Mobility anchor

**Activation et fonctionnement :** Un faucon survole une zone choisie.
Il fournit une vue aérienne simplifiée sous forme de pings de mouvement
et peut servir une seule fois de point d'ancrage pour un saut/dash du
lanceur.

**Mécanique réelle :** Après utilisation comme ancre, le faucon s'enfuit
immédiatement. Tant qu'il reste en observation, il peut être abattu.

**Synergies / intérêt :** Outil hybride reconnaissance/mobilité à forte
valeur tactique.

**Contre-jeu :** Invocation visible, destructible et information
volontairement imprécise : pas de wallhack permanent.

**A --- Réservoir de chakra scellé**

**Tags :** Stored resource, Delayed payoff, Risk

**Activation et fonctionnement :** Le joueur canalise pour stocker une
portion de son chakra actuel dans un sceau personnel. Tant que le sceau
reste fermé, sa réserve maximale disponible est réduite d'autant.

**Mécanique réelle :** À n'importe quel moment ultérieur du combat, il
peut briser le sceau pour récupérer instantanément la quantité stockée
et gagner une brève résistance aux interruptions de mudra.

**Synergies / intérêt :** Permet de préparer un second souffle au prix
d'être volontairement plus faible avant.

**Contre-jeu :** Canalisation initiale vulnérable et perte stratégique
si le joueur meurt ou n'a jamais l'occasion d'ouvrir le sceau.

## Rang S

**S --- Hiraishin --- Réseau des marques**

**Tags :** Teleport network, Setup, Recast

**Activation et fonctionnement :** Le joueur peut poser jusqu'à quatre
marques spatio-temporelles pendant une longue durée de combat.
L'activation de l'ultime ouvre une fenêtre durant laquelle il peut se
téléporter successivement sur chaque marque une seule fois.

**Mécanique réelle :** À chaque arrivée, il choisit son orientation et
conserve son élan, mais ne bénéficie que d'une très courte
invulnérabilité de matérialisation destinée à éviter le chevauchement.
Les marques ne permettent pas de téléporter de force un ennemi.

**Synergies / intérêt :** Un véritable S de préparation et de mouvement
: plus les marques sont intelligentes, plus le parcours est puissant.

**Contre-jeu :** Les marques sont visibles aux joueurs proches,
destructibles et chaque point n'est utilisable qu'une fois pendant la
fenêtre.

**S --- Huit Portes --- Porte de la Vue**

**Tags :** Extreme mode, Health debt, Lockout

**Activation et fonctionnement :** Le joueur ouvre une Porte supérieure
et gagne un pic massif de vitesse physique, d'accélération et de
résistance aux déplacements forcés. Ses coups créent des ondes d'air
courtes.

**Mécanique réelle :** La jauge de Porte se vide rapidement et chaque
technique physique accélère le drain. À la fermeture, une Dette
corporelle retire progressivement une portion importante de PV et
désactive les dashes pendant un court moment.

**Synergies / intérêt :** Ultime de all-in : extrêmement fort pendant
quelques secondes, mais impossible à utiliser sans accepter une phase de
vulnérabilité réelle.

**Contre-jeu :** Kite, terrain défensif et contrôles de zone restent
efficaces. Aucun nettoyage de la Dette par soin instantané.

**S --- Marque maudite --- Stade II**

**Tags :** Transformation, Mutations, Corruption

**Activation et fonctionnement :** Le joueur transforme complètement la
Marque maudite. Il choisit au lancement deux mutations parmi trois :
ailes de mobilité, carapace de garde, membres offensifs.

**Mécanique réelle :** Chaque mutation donne une nouvelle propriété mais
la Corruption augmente en continu. À saturation, le mode s'arrête
brutalement et le joueur subit une période où son chakra maximal est
temporairement réduit.

**Synergies / intérêt :** Ultime personnalisable à chaque activation,
permettant un build adapté à la situation.

**Contre-jeu :** Deux choix seulement, dette lourde et silhouettes des
mutations immédiatement lisibles pour l'adversaire.

**S --- Barrière spatio-temporelle**

**Tags :** Portal shield, Capture projectile, Recast

**Activation et fonctionnement :** Un portail défensif large s'ouvre
devant le joueur pendant une très courte durée. Les projectiles et
techniques linéaires non ultimes qui y entrent sont retirés du terrain
et stockés comme Masse spatiale.

**Mécanique réelle :** Réactiver ouvre une sortie à un autre point
proche et recrache cette Masse sous forme d'une onde neutre unique, dont
taille et poussée dépendent de ce qui a été absorbé, avec dégâts
plafonnés.

**Synergies / intérêt :** Défense de timing pouvant convertir une salve
ennemie en repositionnement offensif.

**Contre-jeu :** Orientation fixe, fenêtre courte, aucune absorption des
mêlées, zones ou ultimes. Si rien n'est capté, l'ultime est largement
gaspillé.

**S --- Légion des clones d'ombre**

**Tags :** Multi-body, Shared command, Resource split

**Activation et fonctionnement :** Le joueur crée un groupe important de
clones fragiles. Au lieu d'avoir chacun une IA complète, ils reçoivent
trois ordres successifs choisis par le joueur : charger un point,
encercler une cible ou lancer une attaque basique synchronisée.

**Mécanique réelle :** Chaque ordre consomme une part du chakra total
investi. Les clones meurent rapidement mais forcent l'adversaire à lire
la formation et les angles.

**Synergies / intérêt :** Ultime stratégique d'espace et de surcharge
visuelle, contrôlé par commandes plutôt que par auto-aim.

**Contre-jeu :** AOE puissantes et défense de zone nettoient très bien
les clones. Le joueur partage une grosse partie de son chakra avec eux
et reste vulnérable.

**S --- Sphère spirale --- Effondrement**

**Tags :** Charged melee projectile, Knockback, Recast

**Activation et fonctionnement :** Le joueur forme une sphère de chakra
instable en avançant lentement. Il peut soit frapper au corps à corps,
soit réactiver pour la projeter sur une courte distance.

**Mécanique réelle :** Au contact, la sphère n'explose pas immédiatement
: elle aspire légèrement vers son centre pendant une fraction de seconde
puis expulse violemment. La version lancée a moins de dégâts mais une
zone plus large.

**Synergies / intérêt :** Choix clair entre finisher rapproché et
contrôle de zone à distance limitée.

**Contre-jeu :** Charge très visible, mobilité réduite, possibilité
d'interrompre avant formation complète et portée de lancer
volontairement courte.

**S --- Domaine d'extinction du chakra**

**Tags :** Domaine, Anti-cast, Symmetric rule

**Activation et fonctionnement :** Une grande zone est scellée pendant
quelques secondes. À l'intérieur, chaque jutsu utilisé ajoute une charge
d'Extinction au lanceur de ce jutsu. À 3 charges, son prochain jutsu est
automatiquement retardé par un long mudra supplémentaire puis ses
charges disparaissent.

**Mécanique réelle :** La règle s'applique aussi au propriétaire du
domaine. Les attaques physiques et outils restent inchangés.

**Synergies / intérêt :** Ultime de contrôle du rythme qui punit le spam
de sorts des deux côtés et favorise la planification.

**Contre-jeu :** Aucun silence immédiat, zone fixe et règle symétrique.
Quitter le domaine retire progressivement les charges.

**S --- Transfert céleste interdit**

**Tags :** Target reposition, Ally rescue, Enemy consent condition

**Activation et fonctionnement :** Le joueur marque un point puis
canalise sur un allié ou sur un ennemi déjà sous contrôle dur provenant
d'une autre source. À la fin, la cible est transférée au point marqué.

**Mécanique réelle :** Sur allié, la canalisation est plus courte et
sert de sauvetage. Sur ennemi, le sort ne peut jamais initier seul un
enlèvement : il exige une cible déjà immobilisée et laisse une longue
alerte visuelle permettant à son équipe d'interrompre.

**Synergies / intérêt :** S extrêmement tactique pour sauver un allié ou
convertir un contrôle d'équipe en repositionnement décisif.

**Contre-jeu :** Longue canalisation, point de destination visible et
impossibilité d'utiliser la version offensive sans setup externe.

# 7. Règles d'implémentation recommandées

• Une technique doit séparer CastData, EffectData et RuntimeState. Le
cast décrit ciblage/mudras/recast ; les effets décrivent dégâts,
déplacements, états ; le runtime stocke les objets/charges propres à
l'instance.

• Les ressources de kit (Braise, Charge, Vigueur, Glyphes, Faim,
Hydratation, etc.) doivent être des systèmes nommés et inspectables par
l'UI, pas des variables cachées dispersées dans les scripts.

• Tout déplacement forcé doit avoir une catégorie (push, pull, launch,
drag) et une force standardisée afin que l'Armor/Ténacité puisse
fonctionner de façon cohérente.

• Les hard-CC doivent passer par un gestionnaire commun de diminishing
returns si le jeu permet d'en chaîner plusieurs en équipe.

• Les objets persistants doivent exposer OwnerId, TeamId, Lifetime,
Health, DestroyReason et éventuellement Recall/Consume. Les effets de
terrain doivent être synchronisés serveur.

• Les faux effets d'illusion ne doivent jamais mentir au serveur : le
serveur connaît le vrai objet ; seul le client ciblé reçoit l'entité
visuelle factice. Cela simplifie l'anti-cheat et les replays.

• Pour les copies Uchiha, utiliser des profils de forme autorisés plutôt
qu'exécuter le code d'un autre sort : PROJECTILE_LINE, CONE, DASH,
GROUND_ZONE, etc. Les effets exclusifs ne sont jamais copiés.

• Les valeurs numériques doivent être data-driven et balancées
séparément : damage_base, chakra_cost, cooldown, cast_time, active_time,
recovery, range, projectile_speed, CC_duration, resource_cost, etc.

# 8. Points de lore à valider sans changer les mécaniques

• Senju : cette V1 autorise une expression végétale à haut rang. Si le
Mokuton doit rester exceptionnel dans ton lore, conserver
Vigueur/Rempart/Floraison/Avatar mais remplacer le visuel de bois par
chakra vital, terre vivante ou armure Senju.

• Karatachi : aucune identité de clan personnalisée n'ayant été fournie,
cette V1 propose Corail/Récif/Carapace. C'est le kit le plus facile à
reskin si ton lore Karatachi est différent.

• Roran, Hôki et Hakumei : cette V1 utilise respectivement
éventail/rythme, recherche-mutagènes et assassinat-illusions. Les
mécaniques sont indépendantes des noms et peuvent être renommées si tes
fiches de clan imposent un autre vocabulaire.

• Épéistes : le kit reste volontairement générique pour fonctionner avec
plusieurs armes. Si chaque joueur choisit une des Sept Épées
légendaires, ajouter ensuite un mini-module d'arme spécifique au-dessus
de cet arbre commun plutôt que remplacer les cinq techniques.
