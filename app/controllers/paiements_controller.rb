class PaiementsController < ApplicationController

  before_action :check_register_workflow  
  load_and_authorize_resource

  def create

  end

  def new

   com=Commande.find(params[:commande_id])
   if com.montant_du != 0

    p=com.paiements.create(
      :idlong => (SecureRandom.random_number *10**14).to_s[0,13],
      :amount_cents => com.prochain_paiement,
      :paiement_hash => "paiement en cours...",
      :verif => false)

    p.paiement_hash=hashpaiement(p)
    p.save if p.valid?

    respond_to do |format|
        #décommenter la ligne ci-dessous pour payer par gadz.org
        format.html{redirect_to urlpaiement(p).to_s}
        format.html{redirect_to commande_path(com.id), notice: "Votre paiement a bien été pris en compte." }
      end
    else
      redirect_to commande_path(com.id), alert: "Votre commande est déjà payée en totalité." 
    end
  end

  def index
    authorize! :read_admin, User
    @paiements=Paiement.all
  end

  def show
   authorize! :show, @commandes
   @paiement=Paiement.find(params[:id])
   @commande=@paiement.commande
   @personne=@commande.personne
   @referant=@personne.referant
   @url=urlpaiement(@paiement)
  end

 def update
 end

 private
 def site
  return "PayResaSKZ"
 end
def ref
  return 126
end

def hashpaiement(paiement)
  secret = Configurable[:secret_paiement]
  return Digest::SHA1.hexdigest( paiement.amount_euro.to_s + '+' + paiement.commande.personne.email + '+' + ref.to_s + '+' + site + '+' + secret)
end
    ###################################################################
    # Copyright (c) 2012 Thomas Fuzeau
    # Under MIT licence.
    # More info: http://opensource.org/licenses/mit-license.php
    ###################################################################
    def urlpaiement(paiement)
      # order = transaction.order
      r=paiement.commande.personne.user.referant
      require 'addressable/uri'
      require 'addressable/template'

      
      
      template = Addressable::Template.new("https://www.gadz.org/external/payment/{ref}/montant/{amount}")

      params = {
        :firstname => r.nom,
        :lastname => r.prenom,
        :email => r.email,
        :sex => r.genre.nom_cas,
        :phone => r.phone,
        :address => [r.adresse," " ,r.complement, " ",r.codepostal, " ",r.ville].join, #[current_user.address_1, current_user.address_2, current_user.postcode, current_user.city].join(" "),
        :op => "submit",
        :order_id => paiement.id,
        :site => site,
        :version => "1",
        :hash => hashpaiement(paiement),
        :cgu => 1
      }
      uri = template.expand({"ref" => ref.to_s, "amount" => paiement.amount_euro.to_s })
      uri.query_values = params
      uri
    end

  end
