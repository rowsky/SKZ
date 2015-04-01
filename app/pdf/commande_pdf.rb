class CommandePdf < Prawn::Document

  SMALL=8
  NORMAL=12
  MEDIUM=15
  LARGE=22
  INDENT=20
  PADDINGBX=20

  EURO=I18n.translate(:'number.currency.format', :locale => :fr, :default => {})[:unit]

def initialize(commande, personne,total_euro,paiements)
    super(:page_size=> "A4",:top_margin => 60)

    text "<b>Facture SKZ</b>", :size => LARGE,:inline_format => true
   	draw_text "-> mettre le code barre", :at => [300,700]
    text "Commande # #{commande.idlong}"
   
    move_down PADDINGBX
    info(personne)
    move_down 2*PADDINGBX
    options(commande,total_euro)
    move_down 2*PADDINGBX
    paiements(paiements)

    footer()

end

def info(personne)
	text personne.nom_complet, :style => :bold
	text personne.adresse
	text personne.codepostal.to_s + " " + personne.ville

end

def options(commande,total_euro)
	data = [["Produit","Quantitée", "Prix TTC (€)"]]+commande.commande_products.map { |cprd|  [cprd.product.name,cprd.nombre,cprd.product.price_euro]}+[["Total","",total_euro]]

	text "#{commande.event.name} #{commande.event.description}"
    move_down PADDINGBX

	table(data) do
		cells.padding = 5
		row(0).font_style   = :bold
		width = 500
		row(-1).font_style   = :bold
	end
	end

def paiements(paiements)
	data = [["Date","Montant"]]+ (paiements.map { |p| [p.date.to_s.gsub("UTC",""),p.amount_euro.to_s] if p.verif && !p.erreur?})

	text "<b>Détails des paiements effectués</b>", :size => MEDIUM,:inline_format => true
	table(data.compact) do
		cells.padding = 5
		row(0).font_style   = :bold
	
	end
end
def footer()
	draw_text "Document généré le #{DateTime.now.strftime("%F à %R")}",:at => [0, 0],:size => SMALL
end

end