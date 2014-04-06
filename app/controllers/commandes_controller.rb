# -*- encoding : utf-8 -*-
class CommandesController < ApplicationController

  before_action :check_register_workflow
  helper_method :sort_column, :sort_direction
  

  def new
    if Configurable[:commandes_possibles] == true || @current_user.admin?

      @commande = Commande.new(:personne_id => params[:pers_id])
      authorize! :create, @commande
      @personne=Personne.find_by_id(params[:pers_id]) if params[:pers_id]
      @packs=Pack.all
      @events=Event.all.to_a
      @personne.commandes.each{|c| @events.delete c.event} if @personne
      logger.debug @events.to_s
      @commande.tbk = @personne.default_tbk if @personne
      redirect_to(personne_url(@personne), notice: "Vous êtes déjà inscrit à tout les évènements") if @events.blank?
    else
      redirect_to dashboard_user_path(current_user), alert: "Les commandes sont désormais fermées"
    end
  end

  def create
    # pour la generation du code ean13 qui sert aussi d'id publique:
    # (SecureRandom.random_number *10**14).to_s[0,13]

    @commande = Commande.new(commande_params)
    authorize! :create, @commande

    @commande.idlong=@commande.gen_idlong

    respond_to do |format|
      if @commande.save
        format.html { redirect_to catalogue_commande_path(@commande.id), notice: 'Votre commande a bien été créée' }
        format.json { head :no_content }
      else
        format.html { render 'new' }
        format.json { render json: @user.errors, status: :unprocessable_entity }
      end
    end

  end

  def edit
    set_commande
    authorize! :update, @commande
    @events=Event.all.to_a
    @packs=Pack.all
  end

  def update
    set_commande
    authorize! :create, @commande

    respond_to do |format|
      if @commande.update(commande_params)
        format.html { redirect_to dashboard_user_url @commande.personne.user, notice: 'Votre commande a bien été créée' }
        format.json { head :no_content }
      else
        format.html { render 'edit' }
        format.json { render json: @commande.errors, status: :unprocessable_entity }
      end
    end
  end

  def index
  	@commandes = Commande.order(sort_column + " " + sort_direction).paginate(:page => params[:page])
  	authorize! :show, @commandes

    respond_to do |format|
      format.html
      format.xls
    end

  end

  def export
    pool_size=Configurable[:export__commande_pool_size]
    page_number=params[:page].to_i || 1
    debut=(page_number-1)*pool_size
    fin=(page_number)*pool_size-1
    coms = Commande.all[debut..fin]
    @commandes = coms.map{|c| c.serialize}
    authorize! :show, @commandes

    nbr_pages=(Commande.count/pool_size.to_f).ceil

    respond_to do |format|
      format.xls do
        response.headers['Content-Disposition'] = 'attachment; filename="' +"export_commandes_"+Date.today.to_s+"_"+page_number.to_s+"of"+nbr_pages.to_s+ '.csv"'
      end
    end
  end

  def show
  	@commande = Commande.find(params[:id])
  	authorize! :show, @commande

    @personne = @commande.personne

   	##### à definir quand les associations commande <-> produits seront faites
  	# liste des produit d'une commande
    @produits = @commande.products

   	# total du prix d'une commande
   	# total = @produits.map{|p| p.price}.sum
   	@total_euro = @commande.montant_total.to_i / 100.0

   	# liste des paiements associés à une commande
   	@paiements = @commande.paiements
   	# total des paiements d'une commande pour préparer à la vérification
   	@totalpaiement_euro = @commande.montant_paye / 100.0

   	@paiement_du_euro = @commande.montant_du.to_i / 100.0
   	##### Vérification du statut d'une commande
   	# status = true si:
   	# @total = @totalpaiement ET
   	# (la personne à une assurance ET a donné un justificatif) OU a dans sa commande un produit assurance 
   	
   	# if total_cents == totalpaiement_cents
   	# 	@paiementok = true 
   	# else
   	# 	@paiementok = false
   	# end

   	# assurance_personne = @personne.assurance
   	# assurance_document_personne = @personne.documentassurance
   	# assurance_dans_produit = false #vlaur arbitraire pour test. à coder

   	# if ((@personne.assurance and @personne.documentassurance) or assurance_dans_produit)
   	# 	@assuranceok = true
   	# else
   	# 	@assuranceok = false
   	# end

   	# if @assuranceok && @paiementok
   	# 	@status=true
   	# else
   	# 	@status=false
   	# end

   	@status = @commande.complete?
   end

   def index_remboursement
    commandes=Commande.all
    @commandes_remb=commandes.map{|c| c if c.montant_du < 0 }.compact
   end

   def add_product
    set_commande

    authorize! :add_product, @commande

    @product = Product.find_by_id(params[:product_id])

    if @product
      respond_to do |format|
        if @commande.add_product @product
          format.html { redirect_to @commande }
          format.json { render json: '' }
        else
          format.json { render json: "Error : Can't add", status: :unprocessable_entity }
        end
      end
    else
      respond_to do |format|
        format.json { render json: "Error", status: :unprocessable_entity }
      end
    end
  end

  def remove_product
    set_commande

    authorize! :add_product, @commande

    @product = Product.find_by_id(params[:product_id])

    if @product
      respond_to do |format|
        if @commande.remove_product @product
          format.html { redirect_to @commande }
          format.json { render json: '' }
        else
          format.json { render json: "Error : Can't add", status: :unprocessable_entity }
        end
      end
    else
      respond_to do |format|
        format.json { render json: "Error", status: :unprocessable_entity }
      end
    end
  end

  def catalogue
    if Configurable[:commandes_editables] == true || @current_user.admin?
      set_commande
      authorize! :add_product, @commande    

      @categories=Categorie.all.map do|c|

        prods = c.products.where(event_id: @commande.event_id)

        select = @commande.commande_products.select{|cp| cp.product.categorie_id==c.id}.first
        select_id = select ? select.product_id : 0

        {id: c.id,nom: c.nom, max: c.max_par_personne, selected: select_id ,products: prods }

      end
    else
      redirect_to :back, alert: "Les commandes sont désormais bloquées!"
    end

  end

  def maj_cat_product
    set_commande

    authorize! :add_product, @commande

    @product = Product.find_by_id(params[:product_id]||0)
    @cat = Categorie.find(params[:categorie_id])

    ok = true
    ok = false unless (@cat.products.include?(@product)|| not(@product))

    if ok

      @cat.products.each do |p|
        @commande.commande_products.where(product_id: p.id).delete_all
      end


      respond_to do |format|
        if not(@product) || @commande.add_product(@product)
          format.html { redirect_to @commande }
          format.json { render json: '' }
        else
          format.json { render json: "Error : Can't add", status: :unprocessable_entity }
        end
      end
    else
      respond_to do |format|
        format.json { render json: "Error", status: :unprocessable_entity }
      end
    end
  end

  def add_caution
    @lastcautioncommandes = lasts_caution_update_commandes_path
    authorize! :show, @commandes

    respond_to do |format|
      format.html
      format.xls
    end
  end

  def lasts_caution_update
    authorize! :show, @commandes

    co = Commande.all.map{|p| p}
    render :json => co

  end

  private

    def set_commande
      @commande = Commande.find(params[:id])
    end

    def commande_params
      params.require(:commande).permit(:personne_id,:event_id,:tbk_id,:glisse_id,:caution)
    end

    def sort_column
      Commande.column_names.include?(params[:sort]) ? params[:sort] : "created_at"
    end
    
    def sort_direction
      %w[asc desc].include?(params[:direction]) ? params[:direction] : "asc"
    end

end
