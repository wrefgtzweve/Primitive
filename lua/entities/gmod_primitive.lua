AddCSLuaFile()
DEFINE_BASECLASS("base_anim")

ENT.PrintName = "gmod_primitive"
ENT.Category = "gmod_primitive"
ENT.Author = "shadowscion"
ENT.AdminOnly = false
ENT.Spawnable = true
ENT.RenderGroup = RENDERGROUP_BOTH

cleanup.Register("gmod_primitive")

local wireframe = Material("sprops/sprops_grid_12x12")

function ENT:SpawnFunction(ply, tr, ClassName)
	if not tr.Hit then
		return
	end

	local ent = ents.Create(ClassName)
	ent:SetModel("models/hunter/blocks/cube025x025x025.mdl")
	ent:SetPos(tr.HitPos + tr.HitNormal*ent:Get_primitive_dz())
	ent:Spawn()
	ent:Activate()

	return ent
end

function ENT:SetupDataTables()
	local cat = "Config"
	self:NetworkVar("String", 0, "_primitive_type", {KeyName="_primitive_type",Edit={order=100,category=cat,title="Type",type="Combo",colorOverride=true,text="cube",
		values={cube="cube",cylinder="cylinder",tube="tube",wedge="wedge",wedge_corner="wedge_corner",pyramid="pyramid"}}})
	self:NetworkVar("Bool", 0, "_primitive_dbg", {KeyName="_primitive_dbg",Edit={order=101,category=cat,title="Debug",type="Boolean"}})

	local cat = "Dimensions"
	self:NetworkVar("Float", 0, "_primitive_dx", {KeyName="_primitive_dx",Edit={order=200,category=cat,title="Length X",type="Float",min=0.5,max=512}})
	self:NetworkVar("Float", 1, "_primitive_dy", {KeyName="_primitive_dy",Edit={order=201,category=cat,title="Length Y",type="Float",min=0.5,max=512}})
	self:NetworkVar("Float", 2, "_primitive_dz", {KeyName="_primitive_dz",Edit={order=202,category=cat,title="Length Z",type="Float",min=0.5,max=512}})

	local cat = "Modifiers"
	self:NetworkVar("Int", 0, "_primitive_segments", {KeyName="_primitive_segments",Edit={order=300,category=cat,title="Segments",type="Int",min=1,max=32}})
	self:NetworkVar("Float", 3, "_primitive_thickness", {KeyName="_primitive_thickness",Edit={order=301,category=cat,title="Thickness",type="Float",min=0,max=512}})

	self:NetworkVarNotify("_primitive_type", self._primitive_trigger_update)
	self:NetworkVarNotify("_primitive_dx", self._primitive_trigger_update)
	self:NetworkVarNotify("_primitive_dy", self._primitive_trigger_update)
	self:NetworkVarNotify("_primitive_dz", self._primitive_trigger_update)
	self:NetworkVarNotify("_primitive_segments", self._primitive_trigger_update)
	self:NetworkVarNotify("_primitive_thickness", self._primitive_trigger_update)

	if SERVER then
		self:Set_primitive_type("cube")
		self:Set_primitive_dbg(false)
		self:Set_primitive_dx(48)
		self:Set_primitive_dy(48)
		self:Set_primitive_dz(48)
		self:Set_primitive_segments(32)
		self:Set_primitive_thickness(1)
	end

	self.queue_rebuild = CurTime()
end

function ENT:_primitive_trigger_update(name, old, new)
	if old == new then
		return
	end
	self.queue_rebuild = CurTime()
end

function ENT:RebuildPhysics(pmesh)
	if not pmesh then
		return
	end

	local contraints
	if SERVER then
		contraints = {}
		for _, v in pairs(constraint.GetTable(self) ) do
			table.insert(contraints, v)
		end
		constraint.RemoveAll(self)
		self.ConstraintSystem = nil
	end

	local move, sleep
	if SERVER then
		move = self:GetPhysicsObject():IsMoveable()
		sleep = self:GetPhysicsObject():IsAsleep()
	end

	self:PhysicsInitMultiConvex(pmesh)
	self:SetSolid(SOLID_VPHYSICS )
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:EnableCustomCollisions(true)

	local physobj = self:GetPhysicsObject()
	if not SERVER or not physobj or not physobj:IsValid() then
		return
	end

	local dx = self:Get_primitive_dx()
	local dy = self:Get_primitive_dy()
	local dz = self:Get_primitive_dz()

	local density = 0.001
	local mass = (dx * dy * dz)*density

	physobj:SetMass(mass)
	physobj:SetInertia(Vector(dx, dy, dz):GetNormalized()*mass)
	physobj:EnableMotion(move)

	if not sleep then
		physobj:Wake()
	end

	if #contraints > 0 then
		timer.Simple(0, function()
			for _, info in pairs(contraints) do
				local make = duplicator.ConstraintType[info.Type]
				if make then
					local args = {}
					for i = 1, #make.Args do
						args[i] = info[make.Args[i]]
					end
					local new, temp = make.Func(unpack(args))
				end
			end
		end)
	end
end

function ENT:Think()
	if self.queue_rebuild and CurTime() - self.queue_rebuild > 0.015 then
		self.queue_rebuild = nil

		local pmesh, vmesh, verts = PRIMITIVE.Build(self:GetNetworkVars())

		self:RebuildPhysics(pmesh)

		if CLIENT then
			local primitive_type = self:Get_primitive_type()
			local editor = self:GetEditingData()

			if primitive_type == "cube" then
				editor._primitive_dx.enabled = true
				editor._primitive_dy.enabled = true
				editor._primitive_dz.enabled = true
				editor._primitive_thickness.enabled = false
				editor._primitive_segments.enabled = false

			elseif primitive_type == "cylinder" then
				editor._primitive_dx.enabled = true
				editor._primitive_dy.enabled = true
				editor._primitive_dz.enabled = true
				editor._primitive_thickness.enabled = false
				editor._primitive_segments.enabled = true

			elseif primitive_type == "tube" then
				editor._primitive_dx.enabled = true
				editor._primitive_dy.enabled = true
				editor._primitive_dz.enabled = true
				editor._primitive_thickness.enabled = true
				editor._primitive_segments.enabled = true

			end

			if vmesh and #vmesh >= 3 then
				if self.mesh_object and self.mesh_object:IsValid() then
					self.mesh_data = nil
					self.mesh_object:Destroy()
				end
				self.mesh_object = Mesh()
				self.mesh_object:BuildFromTriangles(vmesh)
				self.mesh_data = { Mesh = self.mesh_object, Material = wireframe, verts = verts, tris = #vmesh / 3 }
			end

			local maxs = Vector(self:Get_primitive_dx(), self:Get_primitive_dy(), self:Get_primitive_dz())*0.5
			local mins = maxs * -1

			self:SetRenderBounds(mins, maxs)
			self:SetCollisionBounds(mins, maxs)
		end

		return
	end

	if CLIENT then
		local physobj = self:GetPhysicsObject()
		if physobj:IsValid() then
			physobj:SetPos(self:GetPos())
			physobj:SetAngles(self:GetAngles())
			physobj:EnableMotion(false)
			physobj:Sleep()
		end
	end
end

function ENT:Initialize()
	if SERVER then
		self:DrawShadow(false)
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:SetSolid(SOLID_VPHYSICS)

		return
	end

	if self.mesh_object and self.mesh_object:IsValid() then
		self.mesh_data = nil
		self.mesh_object:Destroy()
	end
end

if CLIENT then
	function ENT:OnRemove()
		timer.Simple(0, function()
			if self and self:IsValid() then
				return
			end
			if self.mesh_object and self.mesh_object:IsValid() then
				self.mesh_data = nil
				self.mesh_object:Destroy()
			end
		end)
	end

	function ENT:GetRenderMesh()
		return self.mesh_data
	end

	local c_red = Color(255, 0, 0, 150)
	local c_grn = Color(0, 255, 0, 150)
	local c_blu = Color(0, 0, 255, 150)
	local c_yel = Color(255, 255, 0, 150)
	local c_cya = Color(0, 255, 255, 10)

	function ENT:Draw()
		self:DrawModel()

		if self:Get_primitive_dbg() then
			local pos = self:GetPos()

			render.DrawLine(pos, pos + self:GetForward()*16, c_grn)
			render.DrawLine(pos, pos + self:GetRight()*16, c_red)
			render.DrawLine(pos, pos + self:GetUp()*16, c_blu)

			local min, max = self:GetRenderBounds()
			render.DrawWireframeBox(pos, self:GetAngles(), min, max, c_cya)

			if self.mesh_data and self.mesh_data.verts then
				cam.Start2D()

				surface.SetFont("Default")
				surface.SetTextColor(c_yel)

				local pos = self:LocalToWorld(max * 1.1):ToScreen()

				surface.SetTextPos(pos.x, pos.y)
				surface.DrawText(string.format("verts (%d)", #self.mesh_data.verts))
				surface.SetTextPos(pos.x, pos.y + 16)
				surface.DrawText(string.format("tris (%d)", self.mesh_data.tris))

				for k, v in ipairs(self.mesh_data.verts) do
					local pos = self:LocalToWorld(v):ToScreen()
					surface.SetTextPos(pos.x, pos.y)
					surface.DrawText(k - 0)
				end

				cam.End2D()
			end
		end
	end
end
